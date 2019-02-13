# Class representing a place
class Place
  attr_accessor :id, :formatted_address, :location, :address_components
  def initialize(_id:, address_components:, formatted_address:, geometry:)
    @id = (_id.is_a? BSON::ObjectId) ? _id.to_s : _id
    @address_components = address_components.map { |a| AddressComponent.new(a) }
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
end
