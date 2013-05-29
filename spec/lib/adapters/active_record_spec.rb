require 'spec_helpers/boot'

if defined?(ActiveRecord)
  load 'spec_helpers/adapters/active_record.rb'

  describe Protector::Adapters::ActiveRecord do
    before(:all) do
      load 'migrations/active_record.rb'

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

    #
    # Model instance
    #
    describe Protector::Adapters::ActiveRecord::Base do
      let(:dummy) do
        Class.new(ActiveRecord::Base) do
          self.table_name = "dummies"
          scope :none, where('1 = 0') unless respond_to?(:none)
        end
      end

      it "includes" do
        Dummy.ancestors.should include(Protector::Adapters::ActiveRecord::Base)
      end

      it "scopes" do
        scope = Dummy.restrict!('!')
        scope.should be_a_kind_of ActiveRecord::Relation
        scope.protector_subject.should == '!'
      end

      it_behaves_like "a model"
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
      end

      it "forwards subject" do
        Dummy.restrict!('!').where(number: 999).first.protector_subject.should == '!'
        Dummy.restrict!('!').where(number: 999).to_a.first.protector_subject.should == '!'
      end

      context "with null relation" do
        it "checks existence" do
          Dummy.any?.should == true
          Dummy.restrict!('-').any?.should == false
        end

        it "counts" do
          Dummy.count.should == 4
          Dummy.restrict!('-').count.should == 0
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
        end

        it "counts" do
          Dummy.count.should == 4
          Dummy.restrict!('+').count.should == 2
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

      #
      # Eager loading
      #
      describe "eager loading" do
        it "scopes" do
          d = Dummy.restrict!('+').includes(:fluffies)
          d.length.should == 2
          d.first.fluffies.length.should == 1
        end

        context "joined to filtered association" do
          it "scopes" do
            d = Dummy.restrict!('+').includes(:fluffies).where(fluffies: {number: 777})
            d.length.should == 2
            d.first.fluffies.length.should == 1
          end
        end

        context "joined to plain association" do
          it "scopes" do
            d = Dummy.restrict!('+').includes(:bobbies, :fluffies).where(
              bobbies: {number: 777}, fluffies: {number: 777}
            )
            d.length.should == 2
            d.first.fluffies.length.should == 1
            d.first.bobbies.length.should == 1
          end
        end

        context "with complex include" do
          it "scopes" do
            d = Dummy.restrict!('+').includes(fluffies: :loony).where(
              fluffies: {number: 777},
              loonies: {string: 'zomgstring'}
            )
            d.length.should == 2
            d.first.fluffies.length.should == 1
            d.first.fluffies.first.loony.should be_a_kind_of(Loony)
          end
        end
      end
    end
  end

end