# Base class for events. NOT TO BE INHERITED BY ANYTHING UNLESS YOU REALLY NEED TO, use the `event` macro instead. HERE BE DRAGONS!
abstract class Event
  def initialize
    raise "Event should never be initialized!"
  end
end


# Creates a new event, attempts to bind itself to instances of a class if it's first argument is a self
macro event(event_name, *args)
  _event({{event_name}}, {{args.splat}})

  {% if args.size > 0 && args[0].type.is_a?(Self) %}
    _attach_self({{event_name}})
  {% end %}
end

# Creates a new event
macro _event(event_name, *args)
  {% raise "event_name should be a Path" unless event_name.is_a? Path %}

  # Create our event class
  class {{event_name}} < Event
    # Alias for the callback.
    alias Callback = Proc({{(args.map {|arg| (arg.type.is_a? Self) ? @type : arg.type }).splat}}{% if args.size > 0 %}, {% end %}Nil)

    # Callbacks tied to this event, all of them will be called when triggered
    @@callback : Callback = ->({{args.map{ |a| "#{a.var} : #{(arg.type.is_a? Self) ? @type : arg.type}".id }.splat}}) {  nil }

    # Types of the arguments for the callback event
    ARG_TYPES = {
      {% for arg in args %}
        {{arg.var.stringify}} => {{(arg.type.is_a? Self) ? @type : arg.type}},
      {% end %}
    } of String => Object.class

    # Adds the block to the callbacks
    def self.add_callback(&block : Callback)
      old = @@callback
      @@callback = Callback.new do {% if args.size > 0 %}|{{args.map { |a| a.var }.splat}}|{% end %}
        old.call({{args.map { |a| a.var }.splat}})
        block.call({{args.map { |a| a.var }.splat}})
      end
    end

    # Triggers all the callbacks
    def self.trigger({{args.map {|a| a.var}.splat}}) : Nil
      @@callback.call({{args.map {|a| a.var}.splat}})
    end

    # Clears all the callbacks
    def self.clear
      @@callback = ->({{args.map{ |a| "#{a.var} : #{(a.type.is_a? Self) ? @type : a.type}".id }.splat}}) {  nil }
    end
  end
end

# Attaches this event to the class its run under
macro _attach_self(event_name)
  #TODO: Do check to make sure @type isnt a struct
  {% if args = parse_type("#{event_name}::ARG_TYPES").resolve? %}
    class {{event_name}} < Event
      alias SelfCallbackProc = Proc({% if args.size > 1 %}{{args.values[1..].splat}}, {% end %}Nil)

      # Triggers all the callbacks
      def self.trigger({{args.keys.map(&.id).splat}}) : Nil
        {{args.keys[0].id}}.run_{{event_name.names.last.underscore}}({{args.keys[1..].map(&.id).splat}})

        @@callback.not_nil!.call({{args.keys.map(&.id).splat}})
      end
    end

    @%callback_{event_name.id.underscore} : {{event_name}}::SelfCallbackProc = {{event_name}}::SelfCallbackProc.new { {% if args.size > 1 %}|{{args.keys[1..].map(&.id).splat}}|{% end %} nil }

    def on_{{event_name.names.last.underscore}}(&block : {{event_name}}::SelfCallbackProc)
      @%callback_{event_name.id.underscore} = {{event_name}}::SelfCallbackProc.new do {% if args.size > 1 %}|{{args.keys[1..].map { |a| a.id }.splat}}|{% end %}
        block.call({{args.keys[1..].map { |a| a.id }.splat}})
      end
    end

    def on_{{event_name.names.last.underscore}}(name : String, &block : {{event_name}}::SelfCallbackProc)
      on_{{event_name.names.last.underscore}}(&block)
    end

    def remove_{{event_name.names.last.underscore}}(name : String)
      @%callback_{event_name.id.underscore} = nil
    end
    
    {% arg_types = [] of MacroId%}
    {% args.each { |k,v| arg_types << "#{k.id} : #{v}".id }%}
    
    def run_{{event_name.names.last.underscore}}({{arg_types[1..].splat}})
      @%callback_{event_name.id.underscore}.not_nil!.call({{args.keys[1..].map {|a| a.id }.splat}}) if @%callback_{event_name.id.underscore}
    end
  {% end %}
end

# Defines a global event callback
macro on(event_name, &block)
  {% raise "event_name should be a Path" unless event_name.is_a? Path %}

  {% if args = parse_type("#{event_name}::ARG_TYPES").resolve? %}
    {% raise "Incorrect arguments for block" unless block.args.size == args.size %}
  {% end %}
  {{event_name}}.add_callback() do {% if block.args.size > 0 %}|{{block.args.splat}}|{% end %}
    {{ block.body }}
    nil
  end
end

# Emits a global event callback
macro emit(event_name, *args)
  {{event_name}}.trigger({{args.splat}})
end