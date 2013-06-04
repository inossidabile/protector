class Perf
  def self.load(adapter)
    perf = Perf.new(adapter.camelize)
    base = Pathname.new(File.expand_path '../..', __FILE__)
    file = base.join(adapter+'_perf.rb').to_s
    perf.instance_eval File.read(file), file
    perf.run!
  end

  def initialize(adapter)
    @blocks = {}
    @adapter = adapter
    @activated = false
    @profiling = {}
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

  def activate(&block)
    @activation = block
  end

  def benchmark(subject, options={}, &block)
    @blocks[subject] = block
  end

  def benchmark!(subject, options={min_percent: 4}, &block)
    @profiling[subject] = options
    benchmark(subject, &block)
  end

  def activated?
    @activated
  end

  def run!
    require 'ruby-prof' if @profiling.any?

    results = {}

    results[:off] = run_state('disabled', :red)

    Protector::Adapters.const_get(@adapter).activate!
    @activation.call
    @activated = true

    results[:on] = run_state('enabled', :green)

    print_block "Total".blue do
      results[:off].keys.each do |k|
        off = results[:off][k]
        on  = results[:on][k]

        print_result k, sprintf("%8s / %8s (%s)", off, on, (on / off).round(2))
      end
    end
  end

  private

  def run_state(state, color)
    data = {}
    prof = @profiling

    print_block "Protector #{state.send color}" do
      @blocks.each do |s, b|
        RubyProf.start if prof.include?(s)

        data[s] = Benchmark.realtime(&b)
        print_result s, data[s].to_s

        if prof.include?(s)
          result = RubyProf.stop 

          printer = RubyProf::FlatPrinter.new(result)
          printer.print(STDOUT, prof[s])
        end
      end
    end

    data
  end

  def print_result(title, time)
    print title.yellow
    print "..."
    puts sprintf("%#{100-title.length-3}s", time)
  end

  def print_block(title)
    puts
    puts title
    puts "-"*100

    yield

    puts "-"*100
    puts
  end
end