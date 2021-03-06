module Cash
  module WriteThrough
    DEFAULT_TTL = 12.hours

    def self.included(active_record_class)
      active_record_class.class_eval do
        include InstanceMethods
        extend ClassMethods
      end
    end

    module InstanceMethods
      def self.included(active_record_class)
        active_record_class.class_eval do
          after_create :add_to_caches
          after_update :update_caches
          after_destroy :remove_from_caches
        end
      end

      def add_to_caches
        InstanceMethods.unfold(self.class, :add_to_caches, self)
      end

      def update_caches
        InstanceMethods.unfold(self.class, :update_caches, self)
      end

      def remove_from_caches
        return if new_record?
        InstanceMethods.unfold(self.class, :remove_from_caches, self)
      end

      def expire_caches
        InstanceMethods.unfold(self.class, :expire_caches, self)
      end

      # seamusabshere 10/09/09: Basic support for STI.
      def shallow_clone
        if self.class.descends_from_active_record? and sti_name = read_attribute(self.class.inheritance_column)
          clone = sti_name.constantize.new
        else
          clone = self.class.new
        end
        clone.instance_variable_set("@attributes", instance_variable_get(:@attributes))
        clone.instance_variable_set("@new_record", new_record?)
        clone
      end

      private
      # This quasi-recursively calls add/update/etc. down the inheritance chain
      # No inheritance (normal):                                          Career.send(X), STOP
      # With inheritance, standard Rails STI:                             ActivatedUser.send(X), User.send(X), STOP
      # With inheritance, Pratik Naik "set_inheritance_column nil" style: SuspendedVote.send(X), STOP
      def self.unfold(klass, operation, object)
        while klass < ActiveRecord::Base && klass.ancestors.include?(WriteThrough)
          klass.send(operation, object)
          break unless klass.inheritance_column.present?
          klass = klass.superclass
        end
      end
    end

    module ClassMethods
      def add_to_caches(object)
        indices.each { |index| index.add(object) }
      end

      def update_caches(object)
        indices.each { |index| index.update(object) }
      end

      def remove_from_caches(object)
        indices.each { |index| index.remove(object) }
      end

      def expire_caches(object)
        indices.each { |index| index.delete(object) }
      end
    end
  end
end
