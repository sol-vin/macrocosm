require "./macrocosm/counter"

output_channel = Channel(Int32).new

spawn do
  while i = output_channel.receive?
    
  end
end

counter(100_000) do |x|
  output_channel.send x
end

output_channel.close
