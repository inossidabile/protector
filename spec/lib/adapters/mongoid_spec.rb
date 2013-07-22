require 'spec_helpers/boot'

if defined?(Mongoid::Document)
  load 'spec_helpers/adapters/mongoid.rb'

  dummy1 = nil
  dummy2 = nil

  describe Protector::Adapters::Mongoid do
    before(:all) do
      load 'migrations/mongoid.rb'

      module ProtectionCase
        extend ActiveSupport::Concern

        included do |klass|
          protect do |x|
            case x
            when '-'
              scope { where('false') } 
            
            when '+'
              scope { where(number: 999) }
              can :view, :dummy_id

            else
              unless Protector.config.paranoid
                scope { all }
              end

              can :view, :dummy_id 
            end
          end
        end
      end

      [Dummy, Fluffy].each{|c| c.send :include, ProtectionCase}

      dummy1 = Dummy.create! string: 'zomgstring', number: 999, text: 'zomgtext'
      dummy2 = Dummy.create! string: 'zomgstring', number: 999, text: 'zomgtext'
      Dummy.create! string: 'zomgstring', number: 777, text: 'zomgtext'
      Dummy.create! string: 'zomgstring', number: 777, text: 'zomgtext'

      [Fluffy, Bobby].each do |m|
        m.create! string: 'zomgstring', number: 999, text: 'zomgtext', dummy_id: dummy1.id
        m.create! string: 'zomgstring', number: 777, text: 'zomgtext', dummy_id: dummy1.id
        m.create! string: 'zomgstring', number: 999, text: 'zomgtext', dummy_id: dummy2.id
        m.create! string: 'zomgstring', number: 777, text: 'zomgtext', dummy_id: dummy2.id
      end

      Fluffy.all.each{|f| Loony.create! fluffy_id: f.id, string: 'zomgstring' }
    end

    it "finds out whether object is Mongoid relation" do
      Protector::Adapters::Mongoid.is?(Dummy).should == true
      Protector::Adapters::Mongoid.is?(Dummy.all).should == true
    end

    it "sets the adapter" do
      Dummy.restrict!('!').protector_meta.adapter.should == Protector::Adapters::Mongoid
    end

    #
    # Model instance
    #
    describe Protector::Adapters::Mongoid::Document do
      let(:dummy) do
        Class.new do
          include Mongoid::Document

          store_in collection: "dummies"

          field :string,   type: String
          field :number,   type: Integer
          field :text,     type: String
          field :dummy_id, type: String
        end
      end

      let(:id_field) { "_id" }
      let(:first_dummy) { Dummy.find(dummy1.id) }
      let(:first_fluffy) { Fluffy.first }

      it "includes" do
        Dummy.ancestors.should include(Protector::Adapters::Mongoid::Document)
      end

      it "scopes" do
        scope = Dummy.restrict!('!')
        scope.should be_a_kind_of Mongoid::Criteria
        scope.protector_subject.should == '!'
      end

      it_behaves_like "a model"
    end
  end
end
