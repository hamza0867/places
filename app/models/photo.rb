class Photo
  require 'exifr/jpeg'
  attr_accessor :id, :location
  attr_writer :contents

  def initialize(doc = nil)
    unless doc.nil?
      @id = doc[:_id].to_s if doc[:_id]
      @location = Point.new(doc[:metadata][:location]) if doc[:metadata] && doc[:metadata][:location]
    end
  end

  def self.mongo_client
    Mongoid::Clients.default
  end

  def self.all(offset = nil, limit = nil)
    res = mongo_client.database.fs.find
    res = res.skip(offset) if offset
    res = res.limit(limit) if limit
    res.map { |doc| new(doc) }
  end

  def self.find(id)
    doc = mongo_client.database.fs.find(_id: BSON::ObjectId.from_string(id)).first
    new(doc) unless doc.nil?
  end

  def persisted?
    !@id.nil?
  end

  def contents
    stored_file = Photo.mongo_client.database.fs.find_one(_id: BSON::ObjectId.from_string(@id))
    if stored_file
      buffer = ''
      stored_file.chunks.reduce([]) { |_x, chunk| buffer << chunk.data.data }
      buffer
    end
  end

  def save
    if persisted?
      docs = Photo.mongo_client.database.fs.find(_id: BSON::ObjectId.from_string(@id))
      metadata = docs.first[:metadata]
      metadata[:location] = @location.to_hash
      docs.update_one('metadata' => metadata)
    else
      gps = EXIFR::JPEG.new(@contents).gps
      @location = Point.new(lng: gps.longitude, lat: gps.latitude)
      description = {}
      description[:content_type] = 'image/jpeg'
      description[:metadata] = { 'location' => @location.to_hash }
      @contents.rewind
      grid_file = Mongo::Grid::File.new(@contents.read, description)
      @contents.rewind
      @id = Photo.mongo_client.database.fs.insert_one(grid_file).to_s
    end
  end

  def destroy
    Photo.mongo_client.database.fs.delete(BSON::ObjectId.from_string(@id))
  end

  def find_nearest_place_id(max_meters)
    res = Place.near(@location, max_meters).limit(1).projection(_id: 1).first[:_id]
    res || nil
  end
end
