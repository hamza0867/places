class AddressComponent
  attr_reader :long_name, :short_name, :types
  def initialize(params)
    long_name, short_name, types = params.values_at(:long_name, :short_name, :types)
    @long_name = long_name
    @short_name = short_name
    @types = types
  end
end
