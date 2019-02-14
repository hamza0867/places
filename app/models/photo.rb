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
      grid_file = Mongo::Grid::File.new(@contents.read, description)
      @id = Photo.mongo_client.database.fs.insert_one(grid_file).to_s
    end
  end
end
