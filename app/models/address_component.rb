class AddressComponent
  attr_reader :long_name, :short_name, :types
  def initialize(long_name:, short_name:, types:)
    @long_name = long_name
    @short_name = short_name
    @types = types
  end
end
