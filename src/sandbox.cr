require "./macrocosm/event"

class Test
  event Run, me : self
end

t = Test.new
t.on_run { puts "In the object"}
on(Test::Run) { |t| puts "Outside the object" }
t2 = Test.new
emit Test::Run, t
emit Test::Run, t2