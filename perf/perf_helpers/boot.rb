class Perf
  def self.load(adapter)
    perf = Perf.new(adapter.camelize)
    base = Pathname.new(File.expand_path '../..', __FILE__)
    file = base.join(adapter+'.rb').to_s
    perf.instance_eval File.read(file), file
    perf.run!
  end

  def initialize(adapter)
    @blocks = {}
    @adapter = adapter
  end

  def migrate
    puts
    print "Running with #{@adapter}: migrating... ".yellow

    load "migrations/#{@adapter.underscore}.rb"

    puts "Done.".yellow
  end

  def seed
    print "Seeding... ".yellow
    yield if block_given?
    puts "Done".yellow
  end

  def benchmark(subject, &block)
    @blocks[subject] = block
  end

  def run!
    puts
    puts "Protector #{'disabled'.red}"
    puts "-"*60

    @blocks.each do |s, b|
      print s.yellow
      print "... "
      print Benchmark.realtime(&b).to_s.bold
      puts
    end

    puts "-"*60
    puts

    Protector::Adapters.const_get(@adapter).activate!

    puts "Protector #{'enabled'.green}"
    puts "-"*60

    @blocks.each do |s, b|
      print s.yellow
      print "... "
      print Benchmark.realtime(&b).to_s.bold
      puts
    end

    puts "-"*60
    puts
  end
end