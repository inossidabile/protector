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

benchmark 'Selection' do
  a = ''
  10_000.times { a += '.' }
end