require 'spec_helpers/boot'

if defined?(ActiveRecord)
  load 'spec_helpers/adapters/active_record.rb'

  describe Protector::Adapters::ActiveRecord do
    before(:all) do
      load 'migrations/active_record.rb'

      module ProtectionCase
        extend ActiveSupport::Concern

        included do |klass|
          protect do |x|
            if x == '-'
              scope{ where('1=0') }
            elsif x == '+'
              scope{ where(klass.table_name => {number: 999}) }
            end

            can :read, :dummy_id unless x == '-'
          end
        end
      end

      [Dummy, Fluffy].each{|c| c.send :include, ProtectionCase}

      Dummy.create! string: 'zomgstring', number: 999, text: 'zomgtext'
      Dummy.create! string: 'zomgstring', number: 999, text: 'zomgtext'
      Dummy.create! string: 'zomgstring', number: 777, text: 'zomgtext'
      Dummy.create! string: 'zomgstring', number: 777, text: 'zomgtext'

      [Fluffy, Bobby].each do |m|
        m.create! string: 'zomgstring', number: 999, text: 'zomgtext', dummy_id: 1
        m.create! string: 'zomgstring', number: 777, text: 'zomgtext', dummy_id: 1
        m.create! string: 'zomgstring', number: 999, text: 'zomgtext', dummy_id: 2
        m.create! string: 'zomgstring', number: 777, text: 'zomgtext', dummy_id: 2
      end

      Fluffy.all.each{|f| Loony.create! fluffy_id: f.id, string: 'zomgstring' }
    end

    let(:dummy) do
      Class.new(ActiveRecord::Base) do
        def self.name; 'Dummy'; end
        def self.model_name; ActiveModel::Name.new(self, nil, "dummy"); end
        self.table_name = "dummies"
        scope :none, where('1 = 0') unless respond_to?(:none)
      end
    end

    describe Protector::Adapters::ActiveRecord do
      it "finds out whether object is AR relation" do
        Protector::Adapters::ActiveRecord.is?(Dummy).should == true
        Protector::Adapters::ActiveRecord.is?(Dummy.every).should == true
      end

      it "sets the adapter" do
        Dummy.restrict!('!').protector_meta.adapter.should == Protector::Adapters::ActiveRecord
      end
    end

    #
    # Model instance
    #
    describe Protector::Adapters::ActiveRecord::Base do
      it "includes" do
        Dummy.ancestors.should include(Protector::Adapters::ActiveRecord::Base)
      end

      it "scopes" do
        scope = Dummy.restrict!('!')
        scope.should be_a_kind_of ActiveRecord::Relation
        scope.protector_subject.should == '!'
      end

      it_behaves_like "a model"

      it "validates on create" do
        dummy.instance_eval do
          protect do; end
        end

        instance = dummy.restrict!('!').create(string: 'test')
        instance.errors[:base].should == ["Access denied to 'string'"]
        instance.delete
      end

      it "validates on create!" do
        dummy.instance_eval do
          protect do; end
        end

        expect { dummy.restrict!('!').create!(string: 'test').delete }.to raise_error
      end

      it "validates on new{}" do
        dummy.instance_eval do
          protect do; end
        end

        result = dummy.restrict!('!').new do |instance|
          instance.protector_subject.should == '!'
        end

        result.protector_subject.should == '!'
      end

      it "finds with scope on id column" do
        dummy.instance_eval do
          protect do
            scope { where(id: 1) }
          end
        end

        expect { dummy.restrict!('!').find(1) }.to_not raise_error
        expect { dummy.restrict!('!').find(2) }.to raise_error
      end

      it "allows for validations" do
        dummy.instance_eval do
          validates :string, presence: true
          protect do; can :create; end
        end

        instance = dummy.restrict!('!').new(string: 'test')
        instance.save.should == true
        instance.delete
      end
    end

    #
    # Model scope
    #
    describe Protector::Adapters::ActiveRecord::Relation do
      it "includes" do
        Dummy.none.ancestors.should include(Protector::Adapters::ActiveRecord::Base)
      end

      it "saves subject" do
        Dummy.restrict!('!').where(number: 999).protector_subject.should == '!'
        Dummy.restrict!('!').except(:order).protector_subject.should == '!'
        Dummy.restrict!('!').only(:order).protector_subject.should == '!'
      end

      it "forwards subject" do
        Dummy.restrict!('!').where(number: 999).first.protector_subject.should == '!'
        Dummy.restrict!('!').where(number: 999).to_a.first.protector_subject.should == '!'
        Dummy.restrict!('!').new.protector_subject.should == '!'
        Dummy.restrict!('!').first.fluffies.new.protector_subject.should == '!'
        Dummy.first.fluffies.restrict!('!').new.protector_subject.should == '!'
      end

      it "checks creatability" do
        Dummy.restrict!('!').creatable?.should == false
        Dummy.restrict!('!').where(number: 999).creatable?.should == false
      end

      context "with open relation" do
        context "adequate", paranoid: false do

          it "checks existence" do
            Dummy.any?.should == true
            Dummy.restrict!('!').any?.should == true
            Dummy.exists?.should == true
            Dummy.restrict!('!').exists?.should == true
          end

          it "counts" do
            Dummy.count.should == 4
            dummy = Dummy.restrict!('!')
            dummy.count.should == 4
            dummy.protector_subject?.should == true
          end

          it "fetches" do
            fetched = Dummy.restrict!('!').to_a

            Dummy.count.should == 4
            fetched.length.should == 4
          end
        end

        context "paranoid", paranoid: true do
          it "checks existence" do
            Dummy.any?.should == true
            Dummy.restrict!('!').any?.should == false
            Dummy.exists?.should == true
            Dummy.restrict!('!').exists?.should == false
          end

          it "counts" do
            Dummy.count.should == 4
            dummy = Dummy.restrict!('!')
            dummy.count.should == 0
            dummy.protector_subject?.should == true
          end

          it "fetches" do
            fetched = Dummy.restrict!('!').to_a

            Dummy.count.should == 4
            fetched.length.should == 0
          end
        end
      end

      context "with null relation" do
        it "checks existence" do
          Dummy.any?.should == true
          Dummy.restrict!('-').any?.should == false
          Dummy.exists?.should == true
          Dummy.restrict!('-').exists?.should == false
        end

        it "counts" do
          Dummy.count.should == 4
          dummy = Dummy.restrict!('-')
          dummy.count.should == 0
          dummy.protector_subject?.should == true
        end

        it "fetches" do
          fetched = Dummy.restrict!('-').to_a

          Dummy.count.should == 4
          fetched.length.should == 0
        end

        it "keeps security scope when unscoped" do
          Dummy.unscoped.restrict!('-').count.should == 0
          Dummy.restrict!('-').unscoped.count.should == 0
        end
      end

      context "with active relation" do
        it "checks existence" do
          Dummy.any?.should == true
          Dummy.restrict!('+').any?.should == true
          Dummy.exists?.should == true
          Dummy.restrict!('+').exists?.should == true
        end

        it "counts" do
          Dummy.count.should == 4
          dummy = Dummy.restrict!('+')
          dummy.count.should == 2
          dummy.protector_subject?.should == true
        end

        it "fetches" do
          fetched = Dummy.restrict!('+').to_a

          Dummy.count.should == 4
          fetched.length.should == 2
        end

        it "keeps security scope when unscoped" do
          Dummy.unscoped.restrict!('+').count.should == 2
          Dummy.restrict!('+').unscoped.count.should == 2
        end
      end
    end

    #
    # Model scope
    #
    describe Protector::Adapters::ActiveRecord::Association do
      describe "validates on create! within association" do
        it "when restricted from entity" do
          expect { Dummy.first.restrict!('-').fluffies.create!(string: 'test').delete }.to raise_error
        end

        it "when restricted from association" do
          expect { Dummy.first.fluffies.restrict!('-').create!(string: 'test').delete }.to raise_error
        end
      end

      context "singular association" do
        it "forwards subject" do
          Fluffy.restrict!('!').first.dummy.protector_subject.should == '!'
          Fluffy.first.restrict!('!').dummy.protector_subject.should == '!'
        end

        it "forwards cached subject" do
          Dummy.first.fluffies.restrict!('!').first.dummy.protector_subject.should == '!'
        end
      end

      context "collection association" do
        it "forwards subject" do
          Dummy.restrict!('!').first.fluffies.protector_subject.should == '!'
          Dummy.first.restrict!('!').fluffies.protector_subject.should == '!'
          Dummy.restrict!('!').first.fluffies.new.protector_subject.should == '!'
          Dummy.first.restrict!('!').fluffies.new.protector_subject.should == '!'
          Dummy.first.fluffies.restrict!('!').new.protector_subject.should == '!'
        end

        context "with open relation" do
          context "adequate", paranoid: false do

            it "checks existence" do
              Dummy.first.fluffies.any?.should == true
              Dummy.first.restrict!('!').fluffies.any?.should == true
              Dummy.first.fluffies.restrict!('!').any?.should == true
              Dummy.first.restrict!('!').fluffies.exists?.should == true
              Dummy.first.fluffies.restrict!('!').exists?.should == true
            end

            it "counts" do
              Dummy.first.fluffies.count.should == 2

              fluffies = Dummy.first.restrict!('!').fluffies
              fluffies.count.should == 2
              fluffies.protector_subject?.should == true

              fluffies = Dummy.first.fluffies.restrict!('!')
              fluffies.count.should == 2
              fluffies.protector_subject?.should == true
            end

            it "fetches" do
              Dummy.first.fluffies.count.should == 2
              Dummy.first.restrict!('!').fluffies.length.should == 2
              Dummy.first.fluffies.restrict!('!').length.should == 2
            end
          end

          context "paranoid", paranoid: true do
            it "checks existence" do
              Dummy.first.fluffies.any?.should == true
              Dummy.first.restrict!('!').fluffies.any?.should == false
              Dummy.first.fluffies.restrict!('!').any?.should == false
              Dummy.first.restrict!('!').fluffies.exists?.should == false
              Dummy.first.fluffies.restrict!('!').exists?.should == false
            end

            it "counts" do
              Dummy.first.fluffies.count.should == 2

              fluffies = Dummy.first.restrict!('!').fluffies
              fluffies.count.should == 0
              fluffies.protector_subject?.should == true

              fluffies = Dummy.first.fluffies.restrict!('!')
              fluffies.count.should == 0
              fluffies.protector_subject?.should == true
            end

            it "fetches" do
              Dummy.first.fluffies.count.should == 2
              Dummy.first.restrict!('!').fluffies.length.should == 0
              Dummy.first.fluffies.restrict!('!').length.should == 0
            end
          end
        end
      end

      context "with null relation" do
        it "checks existence" do
          Dummy.first.fluffies.any?.should == true
          Dummy.first.fluffies.exists?.should == true
          Dummy.first.restrict!('-').fluffies.any?.should == false
          Dummy.first.fluffies.restrict!('-').any?.should == false
          Dummy.first.restrict!('-').fluffies.exists?.should == false
          Dummy.first.fluffies.restrict!('-').exists?.should == false
        end

        it "counts" do
          Dummy.first.fluffies.count.should == 2

          fluffies = Dummy.first.restrict!('-').fluffies
          fluffies.count.should == 0
          fluffies.protector_subject?.should == true

          fluffies = Dummy.first.fluffies.restrict!('-')
          fluffies.count.should == 0
          fluffies.protector_subject?.should == true
        end

        it "fetches" do
          Dummy.first.fluffies.count.should == 2
          Dummy.first.restrict!('-').fluffies.length.should == 0
          Dummy.first.fluffies.restrict!('-').length.should == 0
        end
      end

      context "with active relation" do
        it "checks existence" do
          Dummy.first.fluffies.any?.should == true
          Dummy.first.fluffies.exists?.should == true
          Dummy.first.restrict!('+').fluffies.any?.should == true
          Dummy.first.fluffies.restrict!('+').any?.should == true
          Dummy.first.restrict!('+').fluffies.exists?.should == true
          Dummy.first.fluffies.restrict!('+').exists?.should == true
        end

        it "counts" do
          Dummy.first.fluffies.count.should == 2

          fluffies = Dummy.first.restrict!('+').fluffies
          fluffies.count.should == 1
          fluffies.protector_subject?.should == true

          fluffies = Dummy.first.fluffies.restrict!('+')
          fluffies.count.should == 1
          fluffies.protector_subject?.should == true
        end

        it "fetches" do
          Dummy.first.fluffies.count.should == 2
          Dummy.first.restrict!('+').fluffies.length.should == 1
          Dummy.first.fluffies.restrict!('+').length.should == 1
        end
      end
    end

    #
    # Eager loading
    #
    describe Protector::Adapters::ActiveRecord::Preloader do
      describe "eager loading" do
        it "scopes" do
          d = Dummy.restrict!('+').includes(:fluffies)
          d.length.should == 2
          d.first.fluffies.length.should == 1
        end

        context "joined to filtered association" do
          it "scopes" do
            d = Dummy.restrict!('+').includes(:fluffies).where(fluffies: {string: 'zomgstring'})
            d.length.should == 2
            d.first.fluffies.length.should == 1
          end
        end

        context "joined to plain association" do
          it "scopes" do
            d = Dummy.restrict!('+').includes(:bobbies, :fluffies).where(
              bobbies: {string: 'zomgstring'}, fluffies: {string: 'zomgstring'}
            )
            d.length.should == 2
            d.first.fluffies.length.should == 1
            d.first.bobbies.length.should == 2
          end
        end

        context "with complex include" do
          it "scopes" do
            d = Dummy.restrict!('+').includes(fluffies: :loony).where(
              fluffies: {string: 'zomgstring'},
              loonies: {string: 'zomgstring'}
            )
            d.length.should == 2
            d.first.fluffies.length.should == 1
            d.first.fluffies.first.loony.should be_a_kind_of(Loony)
          end
        end
      end

      context "complicated features" do
        # https://github.com/inossidabile/protector/commit/7ce072aa2074e0f3b48e293b952810f720bc143d
        it "handles scopes with includes" do
          fluffy = Class.new(ActiveRecord::Base) do
            def self.name; 'Fluffy'; end
            def self.model_name; ActiveModel::Name.new(self, nil, "fluffy"); end
            self.table_name = "fluffies"
            scope :none, where('1 = 0') unless respond_to?(:none)
            belongs_to :dummy, class_name: 'Dummy'

            protect do
              scope { includes(:dummy).where(dummies: {id: 1}) }
            end
          end

          expect { fluffy.restrict!('!').to_a }.to_not raise_error
        end

        # https://github.com/inossidabile/protector/issues/42
        if ActiveRecord::Base.respond_to?(:enum)
          context "enums" do
            before(:each) do
              dummy.instance_eval do
                enum number: [ :active, :archived ]
              end
            end

            it "can be read" do
              dummy.instance_eval do
                protect do
                  can :read, :number
                  can :create, :number
                  can :update, :number
                end
              end

              d = dummy.new.restrict!('!')

              expect { d.active! }.to_not raise_error

              d.number.should == 'active'
              d.active?.should == true
              d.archived?.should == false

              d.delete
            end
          end
        end
      end
    end
  end

end
