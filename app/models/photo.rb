class Photo
  attr_accessor :id, :location
  attr_writer :contents

  def initialize(doc)
    @id = doc[:_id].to_s
    @location = Point.new(doc[:metadata][:location])
  end

  def self.mongo_client
    Mongoid::Clients.default
  end
end
