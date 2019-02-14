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

  def persisted?
    !@id.nil?
  end

  def save
    unless persisted?
      gps = EXIFR::JPEG.new(@contents).gps
      @location = Point.new(lng: gps.longitude, lat: gps.latitude)
      description = {}
      description[:content_type] = 'image/jpeg'
      description[:metadata] = { 'location' => @location.to_hash }
      @contents.rewind
      grid_file = Mongo::Grid::File.new(@contents.read, description)
      @id = Photo.mongo_client.database.fs.insert_one(grid_file).to_s
    end
  end
end
