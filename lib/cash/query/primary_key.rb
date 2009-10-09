module Cash
  module Query
    class PrimaryKey < Abstract
      def initialize(active_record, ids, options1, options2)
        super(active_record, options1, options2)
        @expects_array = ids.first.kind_of?(Array)
        @original_ids = ids
        @ids = ids.flatten.compact.uniq.collect do |object|
          object.respond_to?(:quoted_id) ? object.quoted_id : object.to_i
        end
      end

      # seamusabshere 10/09/09: If you're not @expect[ing]_array and your query comes back empty, I bet returning nil is more useful than [].
      def perform
        return [] if @expects_array && @ids.empty?
        raise ActiveRecord::RecordNotFound if @ids.empty?

        retval = super(:conditions => { :id => @ids.first })
        retval = nil if !@expects_array and retval.kind_of?(Array) and retval.empty?
        retval
      end

      def order_matters?
        @expects_array
      end
      
      protected
      def deserialize_objects(objects)
        convert_to_active_record_collection(super(objects))
      end

      def cache_keys(attribute_value_pairs)
        @ids.collect { |id| "id/#{id}" }
      end

      def miss(missing_keys, options)
        find_from_keys(*missing_keys)
      end

      def uncacheable
        find_from_ids_without_cache(@original_ids, @options1)
      end

      private
      def convert_to_active_record_collection(objects)
        case objects.size
        when 0
          raise ActiveRecord::RecordNotFound
        when 1
          @expects_array ? objects : objects.first
        else
          objects
        end
      end
    end
  end
end
