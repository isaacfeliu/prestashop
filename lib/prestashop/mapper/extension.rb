module Prestashop
  module Mapper
    module Extension
      module ClassMethods
        def finders(*attr)
          klass = self.singleton_class

          attr.each do |attr_name|
            singleton_class.send :define_method, "find_by_#{attr_name}" do |client, value, options={}|
              find_by(client, { attr_name => value }, options)
            end
          end
        end

        def schema client, include_synopsis=false
          schema_type = include_synopsis ? 'synopsis' : 'blank'
          client.read self.resource, nil, { schema: schema_type }
        end

        def required_fields client
          attributes = schema client, true
          attributes[self.model].select {|k, v| v && v.dig(:attr, :required) }
        end

        # Determinate if model with class resource exists with given id
        #
        #   Car.exists?(1) # => true # if given car exist
        #   Car.exists?(2) # => false # if given car don't exist
        #
        def exists? client, id
          client.check self.resource, id
        end

        # Find model by class resource and given id, returns hash
        # with all nodes, based on node name as key, node value as value
        #
        #   Car.find(1) # => { id: 1, name: 'BMW' }
        #   Car.find(2) # => nil
        #
        def find client, id
          result = client.read self.resource, id
          result ? result[self.model] : nil
        end

        # Find model by class resource and params in hash
        # Returns first result, see #where for more informations
        #
        #   Car.find_by(name: 'BMW') # => 1
        #   Car.find_by(name: 'BMW', display: :full) # => { id: 1, ... }
        #
        def find_by client, filter={}, options = {}
          options.merge!(limit: 1)
          options.merge!(filter: filter)
          where(client, options).first
        end

        # Get models all results by class resource, you can specifi what
        # you should to see as result by specifiyng +:display+
        #
        #   Car.all # => [1,2,3]
        #   Car.all(display: ['name']) # => [{ name: { language: { attr: { id: 2, href: 'http://localhost.com/api/languages/2'}, val: 'BMW 7'} }]
        #
        def all client, options = {}
          result = client.read self.resource, nil, options
          handle_result result, options
        end

        # Get results by class resource and given conditionals
        #
        #   Car.where('filter[id_supplier' => 1) # => [1, 2]
        #
        def where client, options = {}
          result = client.read self.resource, nil, options
          handle_result result, options
        end

        # Destroy model by class resource and given id
        #
        #   Car.destroy(1) # => true
        #
        def destroy client, id
          client.delete self.resource, id
        end

        # Create hash suitable for update, contains #fixed_hash as hash with deleted
        # keys, which shouldn't be in payload, if exist
        #
        #   Car.update_hash(1, name: 'BMW7') # => {name: 'BMW7', manufacturer: 'BMW'}
        #
        def update_hash client, id, options = {}
          original = defined?(fixed_hash) ? fixed_hash(client, id) : find(client, id)
          original.merge(options)
        end

        # Create payload for update, converts hash to XML
        #
        #   Car.update_payload(1, name: 'BMW 7') # => <prestashop xmlns:xlink="http://www.w3.org/1999/xlink"><car><name><![CDATA[BMW 7]]></name></car></prestashop>
        #
        def update_payload client, id, options = {}
          Api::Converter.build(self.resource, self.model, update_hash(client, id, options).except("new"))
        end

        # Update model, with class resource by +id+ and given updates
        #
        #   Car.update(1, name: 'BMW 7') # => {id: 1, name: 'BMW 7'}
        #
        def update client, id, options = {}
          result = client.update self.resource, id, update_payload(client, id, options)
          result ? result[self.model] : nil
        end

        def create(client, hash)
          result = client.create self.resource, self.new(hash).payload
          result ? result[self.model] : nil
        end

        private
          # Handle result to return +id+ or array with +ids+ of requested objects
          #
          #   handle_result({ customers: { customer: [ 1,2 ] } }) # => [1, 2]
          #   handle_result({ customers: { customer: { attr: { id: 1 }} } }) # => [1]
          #   handle_result({ customers: { customer: { attr: { id: '_not_found' }} } }) # => []
          #
          def handle_result result, options = {}
            return [] unless result[self.resource].kind_of?(Hash)

            objects = result[self.resource][self.model]

            return [] unless objects

            array_format = objects.kind_of?(Array)

            if options[:display]
              array_format ? objects : [objects]
            else
              array_format ? objects.map { |o| o[:attr][:id] } : [ objects[:attr][:id] ]
            end
          end
      end

      module InstanceMethods

        # Generate hash with ID
        #
        #   car.hash_id(1) # => {id: 1}
        #
        def hash_id id
          { id: id } if id
        end

        # Make array of unique IDs in hash
        #
        #   car.hash_ids(1,2,3) # => [{id: 1},{id: 2},{id: 3}]
        #
        def hash_ids ids
          ids.flatten.uniq.map{|id| hash_id(id)} if ids
        end

        # Create payload for create new object, coverts hash to XML
        #
        #   car.payload # => '<prestashop xmlns:xlink="http://www.w3.org/1999/xlink"><car><name><![CDATA[BMW 7]]></name><manufacturer><![CDATA[BMW]]></manufacturer></car></prestashop>'
        #
        def payload
          Api::Converter.build(self.class.resource, self.class.model, hash)
        end

        # Create new model from instance, based on class resource a payload generated from
        # hash method
        #
        #   Car.new(name: 'BMW 7', manufacturer: 'BMW').create # => { id: 1, name: 'BMW 7', manufacturer: 'BMW' }
        #
        def create(client)
          result = client.create self.class.resource, payload
          result ? result[self.class.model] : nil
        end
      end

      def self.included(receiver)
        receiver.extend         ClassMethods
        receiver.send :include, InstanceMethods
      end
    end
  end
end
