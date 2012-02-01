begin
  require 'graphviz' 
rescue LoadError 
  $stderr.puts "You must install the 'graphviz' gem to use this visualizer."
  exit
end

begin
  require 'htmlentities' 
rescue LoadError 
  $stderr.puts "You must install the 'htmlentities' gem to use this visualizer."
  exit
end

module Golem
  class Visualizer
    def visualize(statemachine)
      @state_nodes = {}
      @statemachine = statemachine
      @current_path = []
      
      @graph = GraphViz.new(:G, 
        :type => :digraph, 
        :fontname => "Verdana", 
        :concentrate => true)
      
      state = @statemachine.states[@statemachine.initial_state]
      visualize_state(state)
      
      @graph.output(:png => "statemachine.png")
    end
    
    protected
    def visualize_state(state)
      if @current_path.include?(state.name)
        return
      else
        @current_path << state.name        
        #puts @current_path.join(" / ")
      end
      
      @current_path << state.name
      
      html = HTMLEntities.new
      
      if @state_nodes[state.name]
        n = @state_nodes[state.name]
      else
        n = @graph.add_nodes(state.name.to_s)
        
        actions = []
        if state.callbacks[:on_enter]
          action_code = format_callback_code(state.callbacks[:on_enter])
          unless action_code.nil? || action_code.strip.blank?
            actions << "<br /><font face=''>enter/ </font><font face='Courier' point-size='11'>#{html.encode(action_code).gsub("\n","<br align='left' />    ")}</font>"
          end
        end
        if state.callbacks[:on_exit]
          action_code = format_callback_code(state.callbacks[:on_exit])
          unless action_code.nil? || action_code.strip.blank?
            actions << "<br /><font face=''>exit/ </font><font face='Courier' point-size='11'>#{html.encode(action_code).gsub("\n","<br align='left' />    ")}</font>"
          end
        end
        
        n[:fontname] = "Verdana"
        n[:shape] = "box"
        n[:style] = "rounded,filled"
        n[:fillcolor] = "lightblue"
        n[:label] = "<<font>#{state.name}</font>#{actions.join("<br />")}>"
        @state_nodes[state.name] = n
      end
      
      tos = []
      puts state.name.to_s
      @statemachine.events.each do |ev|
        transitions = state.transitions_on_event[ev.name] || []
        transitions.each do |transition|
          puts " --[ #{ev.name} ]--> #{transition.to.name}"
          edge = @graph.add_edges(n, transition.to.name.to_s)
          
          guard = nil
          unless transition.guards.empty?
            guard = transition.guards.collect do |g|
              format_callback_code(g)
            end.join(" and ")
            
            guard = "[#{guard.strip}]\n"
          end
          
          action = nil
          on_transition = transition.callbacks[:on_transition]
          if on_transition
            action = format_callback_code(on_transition)
          end
          
          if action
            action = "<br /> / <font face=\"Courier\" point-size=\"11\">#{html.encode(action).gsub(/\n/,'<br />')}</font> "
          end
          
          if guard
            guard = "<font face=\"Courier\" point-size=\"11\">#{html.encode(guard)}</font><br align=\"left\" />"
          end
          label = "<<font face=\"Verdana\">#{guard}<font face=\"Verdana-Bold\"> #{html.encode(ev.name)} </font> #{action}</font>>"
          edge[:label] = label
          
          tos << transition.to
        end
      end
      
      tos.each do |state|
        visualize_state(state)
      end
    end
    
    def format_callback_code(cb)
      raise ArgumentError, "Callback must be of type Golem::Model::Callback but is a #{callback.type}" unless
        cb.kind_of?(Golem::Model::Callback)
      
      if cb.callback.kind_of?(Symbol)
        action = cb.callback.to_s
      else
        callback_info = cb.to_s.match(/@(.*):([\d]+)/)
        file = callback_info[1]
        line = callback_info[2].to_i - 1
        puts "#{file}:#{line}"
        code = IO.readlines(file)[line].strip
        if /\{(?:\|.+\|)?(.*)\}/ =~ code
          callback_code = $~[1].strip
        elsif /do\s+\|.+\|/ =~ code
          line_code = ""
          callback_code = ""
          while true
            line += 1 
            line_code = IO.readlines(file)[line]
            break if line_code.match(/end/) # FIXME, looking for end of block
            next if line_code.match(/log/) # FIXME, trying to ignore log lines
            callback_code << line_code.strip + "\n   "
          end
        end
        
        return callback_code
      end
    end
  end
end