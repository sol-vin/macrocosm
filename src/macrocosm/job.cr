
macro job(&block)
  %job : Job = Job.new
  {% raise "Block must have 1 argument (a Job)" if block.args.size != 1 %}
  %job = ->({{block.args.first}} : Job) do 
    {{block.body}}
  end.call(%job)

  %job.run
  %job.sync
end

# Creates a job struct type and associated methods/helpers
struct Job
  # Alias for the proc that does the work
  alias Work = Proc(Nil)

  # The proc that holds the work to be done
  @work : Work = -> { nil }

  # Protects @work duing `add_work`and `run`
  @work_mutex : Mutex = Mutex.new

  # Total jobs added to @work
  @total_work_counter : Atomic(Int32) = Atomic(Int32).new(0)

  @done_channel : Channel(Nil) = Channel(Nil).new

  # Adds work to this job. Increases the total work counter.
  def add_work(run_now = false, &block : Work)
    @total_work_counter.add(1)
    if run_now
      spawn do
        block.call
        @done_channel.send nil
      end
    else 
      # Protect @work from other fibers
      @work_mutex.lock
      # Snap shot
      old_work = @work

      # Chains the work procs together. 
      # Not sure if I should do this lol, causes a stack overflow at 173_000 procs deep
      @work = -> do
        old_work.call
        spawn do
          block.call
          @done_channel.send nil
        end
      end
      @work_mutex.unlock
    end
  end

  def run
    @work_mutex.lock
    @work.call
    @work_mutex.unlock
  end

  def sync
    @total_work_counter.get.times do |x|
      @done_channel.receive
    end
  end
end