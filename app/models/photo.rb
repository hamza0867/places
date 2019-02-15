class Photo
  require 'exifr/jpeg'
  attr_accessor :id, :location
  attr_writer :contents

  def initialize(params = nil)
    unless params.nil?
      @id = params[:_id].to_s if params[:_id]
      @location = Point.new(params[:metadata][:location]) if params[:metadata] && params[:metadata][:location]
      @place = params[:metadata][:place] if params[:metadata] && params[:metadata][:place]
    end
  end

  def self.mongo_client
    Mongoid::Clients.default
  end

  def persisted?
    !@id.nil?
  end

  def save
    if persisted?
      doc = self.class.mongo_client.database.fs.find(
        '_id': BSON::ObjectId.from_string(@id)
      ).first
      doc[:metadata][:place] = @place
      doc[:metadata][:location] = @location.to_hash
      self.class.mongo_client.database.fs.find(
        '_id': BSON::ObjectId.from_string(@id)
      ).update_one(doc)
    else
      gps = EXIFR::JPEG.new(@contents).gps
      @location = Point.new(lng: gps.longitude, lat: gps.latitude)
      @contents.rewind
      description = {}
      description[:metadata] = {
        location: location.to_hash,
        place: @place
      }
      description[:content_type] = 'image/jpeg'
      grid_file = Mongo::Grid::File.new(@contents.read, description)
      @contents.rewind
      @id = self.class.mongo_client.database.fs.insert_one(grid_file).to_s
    end
  end

  def self.all(offset = 0, limit = 0)
    mongo_client.database.fs.find.skip(offset).limit(limit)
                .map { |doc| new(doc) }
  end

  def self.find(id)
    id_criteria = BSON::ObjectId.from_string id
    doc = mongo_client.database.fs.find(_id: id_criteria).first
    doc.nil? ? nil : new(doc)
  end

  def contents
    f = self.class.mongo_client.database.fs.find_one(_id: BSON::ObjectId.from_string(@id))
    buffer = ''
    if f
      f.chunks.reduce([]) do |_x, chunk|
        buffer << chunk.data.data
      end
    end
    buffer
  end

  def destroy
    self.class.mongo_client.database.fs.find(_id: BSON::ObjectId.from_string(@id)).delete_one
  end

  def find_nearest_place_id(max_meters)
    Place.near(@location, max_meters).limit(1)
         .projection(_id: 1).first[:_id]
  end

  def place
    @place.nil? ? nil : Place.find(@place.to_s)
  end

  def place=(place)
    @place = place if place.is_a?(BSON::ObjectId)
    @place = BSON::ObjectId.from_string(place) if place.is_a?(String)
    @place = BSON::ObjectId.from_string(place.id) if place.is_a?(Place)
    @place = nil if place.nil?
  end

  def self.find_photos_for_place(place_id)
    id_criteria = place_id.is_a?(BSON::ObjectId) ? place_id : BSON::ObjectId.from_string(place_id)
    mongo_client.database.fs.find('metadata.place' => id_criteria)
  end
end
