macro future(&block)
  Future.new do
    {{ block.body }}
  end
end

class Future(T)
  @value : Atomic(T?) = Atomic(T?).new(nil)
  @exception : Atomic(Exception?) = Atomic(Exception?).new(nil)
  
  def initialize(&block : -> T)
    spawn do
      @value.set block.call
    rescue e
      @exception.set e
    end
  end
  
  def await!
    loop do
      if finished = @value.get
        return finished
      elsif e = @exception.get
        raise e
      end
      Fiber.yield
    end
  end
end