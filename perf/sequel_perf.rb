migrate

seed do
  500.times do
    d = Dummy.create string: 'zomgstring', number: [999,777].sample, text: 'zomgtext'

    2.times do
      f = Fluffy.create string: 'zomgstring', number: [999,777].sample, text: 'zomgtext', dummy_id: d.id
      b = Bobby.create string: 'zomgstring', number: [999,777].sample, text: 'zomgtext', dummy_id: d.id
      l = Loony.create string: 'zomgstring', fluffy_id: f.id
    end
  end
end

activate do
  Dummy.instance_eval do
    protect do
      scope { where }
      can :view, :string
    end
  end

  Fluffy.instance_eval do
    protect do
      scope { where }
      can :view
    end
  end

  # Define attributes methods
  Dummy.first
end

benchmark 'Read from unprotected model (100k)' do
  d = Dummy.first
  100_000.times { d.string }
end

benchmark 'Read open field (100k)' do
  d = Dummy.first
  d = d.restrict!('!') if activated?
  100_000.times { d.string }
end

benchmark 'Read nil field (100k)' do
  d = Dummy.first
  d = d.restrict!('!') if activated?
  100_000.times { d.text }
end

benchmark 'Check existance' do
  scope = activated? ? Dummy.restrict!('!') : Dummy.where
  1000.times { scope.any? }
end

benchmark 'Count' do
  scope = Dummy.limit(1)
  scope = scope.restrict!('!') if activated?
  1000.times { scope.count }
end

benchmark 'Select one' do
  scope = Dummy.limit(1)
  scope = scope.restrict!('!') if activated?
  1000.times { scope.to_a }
end

benchmark 'Select many' do
  scope = Dummy.where
  scope = scope.restrict!('!') if activated?
  200.times { scope.to_a }
end

benchmark 'Select with eager loading' do
  scope = Dummy.eager(:fluffies)
  scope = scope.restrict!('!') if activated?
  200.times { scope.to_a }
end

benchmark 'Select with filtered eager loading' do
  scope = Dummy.eager_graph(fluffies: :loony)
  scope = scope.restrict!('!') if activated?
  200.times { scope.to_a }
end