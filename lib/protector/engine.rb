module Protector
  class Engine < ::Rails::Engine
    config.protector = ActiveSupport::OrderedOptions.new

    initializer "protector.configuration" do |app|
      app.config.protector.each do |key, value|
        Protector.send "#{key}=", value
      end

      if Protector::Adapters::ActiveRecord.modern?
        ActiveRecord::Base.send(:include, Protector::ForbiddenAttributesProtection)
      end
    end
  end

  module ForbiddenAttributesProtection
    def self.sanitize!(args, is_new, meta)
      if is_new
        args[0] = args[0].permit *meta.access[:create].keys
      else
        args[0] = args[0].permit *meta.access[:update].keys
      end
    end

    def sanitize_for_mass_assignment(*args)
      # We check only for updation here since the creation will be handled by relation
      # (see Protector::Adapters::ActiveRecord::Relation#new_with_protector)
      if args.first.respond_to?(:permit) && !new_record? && protector_subject?
        ForbiddenAttributesProtection::sanitize! args, false, protector_meta
      end

      super
    end
  end
end