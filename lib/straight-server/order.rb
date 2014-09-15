module StraightServer
 
  class Order < Straight::Order

    # We explicitly list fields here as not all of them have attr_readers
    # in the original Straight::Order class.
    attr_reader :keychain_id, :amount, :address, :gateway_id, :id

    # Needed to have a class method instead of a simply @@class_var because
    # of the loading order issues. Should probably be refactored in the future.
    def self.dataset
      @@dataset ||= StraightServer.db_connection[:orders]
    end

    # Returns an array of Order objects that satisfy conditions.
    # Conditions are the same as for the Sequel's #where method,
    # however unlike #where, this one returns an actual Array, not
    # a dataset that can be chained with some more conditions.
    def self.find(*attrs)
      dataset.where(*attrs).map { |o| prepare_object(o) }
    end

    def self.find_by_keychain_id(id)
      find(keychain_id: id).first
    end

    def self.find_by_id(id)
      find(id: id).first
    end

    def initialize(*attrs)
      @fields = {}
      super(*attrs)
    end

    # Inserts a new record into the database
    # TODO: should be able to discriminate between new records and
    # an existing record.
    def save
      write_attributes
      if id # existing record
        self.class.dataset.where(id: @id).update(@fields)
      else
        @id = self.class.dataset.insert @fields
      end
      true
    end

    private

      # Takes attributes from various places and assignes them to the
      # hash later to be used to save fields into the DB.
      def write_attributes
        write_attribute(:address,     @address)
        write_attribute(:status,      @status)
        write_attribute(:keychain_id, @keychain_id)
        write_attribute(:amount,      @amount)
        write_attribute(:gateway_id,  @gateway.id)
      end

      def write_attribute(key, value)
        @fields[key] = value
      end

      # Takes a record from the DB and initializes a new Order object with its values.
      def self.prepare_object(record)
        order = self.new(
          amount:      record[:amount],
          gateway:     Gateway.find_by_id(record[:gateway_id]),
          address:     record[:address],
          keychain_id: record[:keychain_id]
        )
        order.instance_variable_set(:@status, record[:status])
        order.instance_variable_set(:@id, record[:id])
        order
      end

  end

end
