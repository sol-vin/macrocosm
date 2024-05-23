macro counter(max, &block)
  %counter = Counter.new
  {{max}}.times do | %x |
    spawn do
      ->({{block.args.first}} : Int32) do 
        {{block.body}}
      end.call(%x)
      %counter.up
    end
  end

  %counter.wait_until({{max}})
end

struct Counter
  @count : Atomic(Int32) = Atomic(Int32).new(0)

  def up
   @count.add(1)
  end

  def wait_until(total)
    until @count.get == total
      Fiber.yield
    end
  end
end

