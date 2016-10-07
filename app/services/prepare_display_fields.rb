class PrepareDisplayFields
  def initialize(client_data_instance)
    @obj = { data: client_data_instance }
    @obj[:special_keys] = load_special_keys
  end

  def run
    process_fields
  end

  def process_fields
    client_display = {}
    @obj[:data].attributes.each do |key, value|
      @obj[:key] = key
      @obj[:value] = value
      client_display[key] = modify_display
    end
    client_display
  end

  def load_special_keys
    Object.const_get(@obj[:data].class.name).special_keys
  end

  def modify_display
    data = @obj[:data]
    key = @obj[:key]
    if data[key].nil?
      "--"
    elsif @obj[:special_keys].include? key
      Object.const_get(data.class.name).send("display_update_" + key, @obj)
    else
      @obj[:value]
    end
  end

  private

  attr_accessor :client_data_instance
end
