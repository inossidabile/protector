module Protector
  module ActiveRecord
    module Adapters
      module StrongParameters
        def self.sanitize!(args, is_new, meta)
          return if args[0].permitted?
          if is_new
            if meta.access.include? :create
              args[0] = args[0].permit(*mapped_permissions(meta.access[:create]))
            end
          else
            if meta.access.include? :update
              args[0] = args[0].permit(*mapped_permissions(meta.access[:update]))
            end
          end
        end

        # Permit nested array of scalar values.
        #
        # can :create, :name, {nicknames: []}, :address
        def self.mapped_permissions(access)
          access.map do |key, value|
            value.nil? ? key : { key => value }
          end
        end

        # strong_parameters integration
        def sanitize_for_mass_assignment(*args)
          # We check only for updation here since the creation will be handled by relation
          # (see Protector::Adapters::ActiveRecord::Relation#new_with_protector and
          # Protector::Adapters::ActiveRecord::Relation#create_with_protector)
          if Protector.config.strong_parameters? && args.first.respond_to?(:permit) \
              && !new_record? && protector_subject?

            StrongParameters.sanitize! args, false, protector_meta
          end

          super
        end
      end
    end
  end
end
