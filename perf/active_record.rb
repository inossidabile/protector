migrate

seed do
  500.times do
    d = Dummy.create! string: 'zomgstring', number: [999,777].sample, text: 'zomgtext'

    2.times do
      f = Fluffy.create! string: 'zomgstring', number: [999,777].sample, text: 'zomgtext', dummy_id: d.id
      b = Bobby.create! string: 'zomgstring', number: [999,777].sample, text: 'zomgtext', dummy_id: d.id
      l = Loony.create! string: 'zomgstring', fluffy_id: f.id
    end
  end
end

activate do
  Dummy.instance_eval do
    protect do
      can :view, :string
    end
  end

  # Define attributes methods
  Dummy.first
end

benchmark 'Reading from unprotected model (100k)' do
  d = Dummy.first
  100_000.times { d.string }
end

benchmark 'Reading open field (100k)' do
  d = Dummy.first
  d = d.restrict!('!') if activated?
  100_000.times { d.string }
end

benchmark 'Reading nil field (100k)' do
  d = Dummy.first
  d = d.restrict!('!') if activated?
  100_000.times { d.text }
end