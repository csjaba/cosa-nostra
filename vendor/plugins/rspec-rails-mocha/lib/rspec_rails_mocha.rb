# copied from rspec-rails and tweaked to work as expected with Mocha

module Spec
  module Rails
    
    unless defined?(IllegalDataAccessException)
      class IllegalDataAccessException < StandardError; end
    end
    
    module Mocha
      
      # Creates a mock object instance for a +model_class+ with common
      # methods stubbed out. Additional methods may be easily stubbed (via
      # add_stubs) if +stubs+ is passed.
      def mock_model(model_class, params = {})
        id = params[:id] || next_id
        model = stub("#{model_class.name}_#{id}", {
          :id => id,
          :to_param => id.to_s,
          :new_record? => false,
          :errors => stub("errors", :count => 0)
        }.update(params))
        
        model.instance_eval <<-CODE
          def as_new_record
            self.stubs(:id).returns(nil)
            self.stubs(:to_param).returns(nil)
            self.stubs(:new_record?).returns(true)
            self
          end
          def is_a?(other)
            #{model_class}.ancestors.include?(other)
          end
          def kind_of?(other)
            #{model_class}.ancestors.include?(other)
          end
          def instance_of?(other)
            other == #{model_class}
          end
          def class
            #{model_class}
          end
        CODE
        
        yield model if block_given?
        return model
      end
      
      module ModelStubber
        def connection
          raise Spec::Rails::IllegalDataAccessException.new("stubbed models are not allowed to access the database")
        end
        def new_record?
          id.nil?
        end
        def as_new_record
          self.id = nil
          self
        end
      end

      # :call-seq:
      #   stub_model(Model)
      #   stub_model(Model).as_new_record
      #   stub_model(Model, hash_of_stubs)
      #
      # Creates an instance of +Model+ that is prohibited from accessing the
      # database*. For each key in +hash_of_stubs+, if the model has a
      # matching attribute (determined by asking it) are simply assigned the
      # submitted values. If the model does not have a matching attribute, the
      # key/value pair is assigned as a stub return value using RSpec's
      # mocking/stubbing framework.
      #
      # <tt>new_record?</tt> is overridden to return the result of id.nil?
      # This means that by default new_record? will return false. If  you want
      # the object to behave as a new record, sending it +as_new_record+ will
      # set the id to nil. You can also explicitly set :id => nil, in which
      # case new_record? will return true, but using +as_new_record+ makes the
      # example a bit more descriptive.
      #
      # While you can use stub_model in any example (model, view, controller,
      # helper), it is especially useful in view examples, which are
      # inherently more state-based than interaction-based.
      #
      # == Database Independence
      #
      # +stub_model+ does not make your examples entirely
      # database-independent. It does not stop the model class itself from
      # loading up its columns from the database. It just prevents data access
      # from the object itself. To completely decouple from the database, take
      # a look at libraries like unit_record or NullDB.
      #
      # == Examples
      #
      #   stub_model(Person)
      #   stub_model(Person).as_new_record
      #   stub_model(Person, :id => 37)
      #   stub_model(Person) do |person|
      #     person.first_name = "David"
      #   end
      def stub_model(model_class, params = {})
        params = params.dup
        model = model_class.new
        model.id = params.delete(:id) || next_id
        
        model.extend ModelStubber
        params.keys.each do |prop|
          model[prop] = params.delete(prop) if model.has_attribute?(prop)
        end
        add_stubs(model, params)
        
        yield model if block_given?
        return model
      end
      
      # Stubs methods on +object+ (if +object+ is a symbol or string a new mock
      # with that name will be created). +stubs+ is a Hash of +method=>value+
      def add_stubs(object, params) # :nodoc:
        m = [String, Symbol].include?(object.class) ? mock(object.to_s) : object
        params.each { |prop, value| m.stubs(prop).returns(value) }
        m
      end

      private
        @@model_id = 1000
        def next_id
          @@model_id += 1
        end

    end
  end
end

Spec::Runner.configure do |config|
  config.mock_with :mocha
  config.include Spec::Rails::Mocha
end