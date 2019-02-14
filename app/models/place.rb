# Class representing a place
class Place
  attr_accessor :id, :formatted_address, :location, :address_components
  def initialize(params)
    _id = params[:_id]
    address_components = params[:address_components]
    formatted_address = params[:formatted_address]
    geometry = params[:geometry]
    @id = (_id.is_a? BSON::ObjectId) ? _id.to_s : _id
    @address_components = address_components.map { |a| AddressComponent.new(a) } unless address_components.nil?
    @formatted_address = formatted_address
    @location = Point.new(geometry[:geolocation])
  end

  def self.mongo_client
    Mongoid::Clients.default
  end

  def self.collection
    mongo_client[:places]
  end

  def self.load_all(f)
    json_string = IO.read f
    data = JSON.parse json_string
    collection.insert_many data
  end

  def self.find_by_short_name(s)
    collection.find("address_components.short_name": s)
  end

  def self.to_places(mg_coll)
    mg_coll.map { |doc| new(doc) }
  end

  def self.find(s)
    id = BSON::ObjectId.from_string s
    doc = collection.find(_id: id).first
    doc ? new(doc) : nil
  end

  def self.all(offset = 0, limit = 0)
    collection.find.skip(offset).limit(limit).map { |doc| new(doc) }
  end

  def self.get_address_components(sort = nil, offset = nil, limit = nil)
    pipeline = []
    pipeline << { '$unwind' => '$address_components' }
    pipeline << { '$project' => { '_id' => 1,\
                                  'address_components' => 1,\
                                  'formatted_address' => 1,\
                                  'geometry.geolocation' => 1 } }
    (pipeline << { '$sort' => sort }) if sort
    (pipeline << { '$skip' => offset }) if offset
    (pipeline << { '$limit' => limit }) if limit
    collection.aggregate(pipeline)
  end

  def self.get_country_names
    pipeline = []
    pipeline << { '$project' => { '_id' => 0,\
                                  'address_components.long_name' => 1,\
                                  'address_components.types' => 1 } }
    pipeline << { '$unwind' =>  '$address_components' }
    pipeline << { '$match' => { 'address_components.types' => 'country' } }
    pipeline << { '$group' => { '_id' => '$address_components.long_name' } }
    collection.aggregate(pipeline).to_a.map { |h| h[:_id] }
  end

  def self.find_ids_by_country_code(country_code)
    pipeline = []
    pipeline << { '$match' => { 'address_components.short_name' => country_code } }
    pipeline << { '$project' => { '_id' => 1 } }
    collection.aggregate(pipeline).map { |doc| doc[:_id].to_s }
  end

  def self.create_indexes
    collection.indexes.create_one('geometry.geolocation' => Mongo::Index::GEO2DSPHERE)
  end

  def self.remove_indexes
    collection.indexes.drop_one('geometry.geolocation_2dsphere')
  end

  def self.near(point, max_meters = nil)
    near = { '$geometry' => point.to_hash }
    near['$maxDistance'] = max_meters unless max_meters.nil?
    collection.find('geometry.geolocation' => {
                      '$near' => near
                    })
  end

  def destroy
    self.class.collection.delete_one(_id: BSON::ObjectId.from_string(@id))
  end

  def near(max_meters = nil)
    res = Place.near(@location.to_hash, max_meters)
    Place.to_places(res)
  end

  def photos(offset = 0, limit = 0)
    Photo.find_photos_for_place(@id).skip(offset)
         .limit(limit).map { |doc| Photo.new(doc) }
  end
end
