module Protector
  module ActiveRecord
    module StrongParameters
      def self.sanitize!(args, is_new, meta)
        if is_new
          args[0] = args[0].permit *meta.access[:create].keys
        else
          args[0] = args[0].permit *meta.access[:update].keys
        end
      end

      # strong_parameters integration
      def sanitize_for_mass_assignment(*args)
        # We check only for updation here since the creation will be handled by relation
        # (see Protector::Adapters::ActiveRecord::Relation#new_with_protector)
        if args.first.respond_to?(:permit) && !new_record? && protector_subject?
          StrongParameters::sanitize! args, false, protector_meta
        end

        super
      end
    end
  end
end