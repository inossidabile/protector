module Protector
  module ActiveRecord
    module Adapters
      module StrongParameters
        def self.sanitize!(args, is_new, meta)
          return if args[0].permitted?
          if is_new
            args[0] = args[0].permit(*meta.access[:create].keys) if meta.access.include? :create
          else
            args[0] = args[0].permit(*meta.access[:update].keys) if meta.access.include? :update
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
