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
    def initialize(statemachine)    
      @statemachine = statemachine
    end
    
    def visualize(format, filename)
      @state_nodes = {}
      @current_path = []
      
      @graph = GraphViz.new(:G, 
        :type => :digraph, 
        :fontname => "Verdana", 
        :concentrate => true)
      
      state = @statemachine.states[@statemachine.initial_state]
      visualize_state(state)
      
      @graph.output(format => filename)
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
        
        if @current_path.first == state.name
          n[:fillcolor] = "palegreen"
        elsif state.transitions_on_event.empty?
          n[:fillcolor] = "red3"
        else
          n[:fillcolor] = "lightblue"
        end
        
        comment = nil
        if state.comment
          comment = "<br /><font color=\"indigo\" font-face=\"Verdana-Italic\" point-size=\"11\">#{html.encode(state.comment).gsub(/\n/,'<br />')}</font>"
        end
        
        n[:label] = "<<font>#{state.name}</font>#{comment}#{actions.join("<br align=\"left\" />")}>"
        @state_nodes[state.name] = n
      end
      
      tos = []
      puts state.name.to_s
      
      @statemachine.events.each do |ev|
        transitions = state.transitions_on_event[ev.name] || []
        
        if transitions.size > 1
          dn = @graph.add_nodes("#{state.name}_#{ev.name}")
          dn[:fontname] = "Verdana"
          dn[:shape] = "diamond"
          dn[:style] = "filled"
          dn[:fillcolor] = "khaki1"
          dn[:label] = ""
          
          de = @graph.add_edges(n, dn)
          de[:label] = "<<font face=\"Verdana-Bold\">#{ev.name}</font>>"
        else
          dn = false
          de = false
        end
        
        transitions.each do |transition|
          puts " --[ #{ev.name} ]--> #{transition.to.name}"
          edge = @graph.add_edges(dn || n, transition.to.name.to_s)
          
          guard = nil
          unless transition.guards.empty?
            guard = transition.guards.collect do |g|
              format_callback_code(g)
            end.join(" and \n")
            
            guard = "[#{guard.strip}]\n"
          end
          
          action = nil
          on_transition = transition.callbacks[:on_transition]
          if on_transition
            action = format_callback_code(on_transition)
          end
          
          if action
            action = "<br /> / <font face=\"Courier\" point-size=\"11\">#{html.encode(action).gsub(/\n/,'<br align="left" />')}</font> "
          end
          
          if guard
            guard = "<font face=\"Courier\" point-size=\"11\">#{html.encode(guard).gsub(/\n/,'<br />')}</font><br align=\"left\" />"
          end
          
          comment = transition.comment
          if comment
            comment = "<font color=\"indigo\" font-face=\"Verdana-Italic\" point-size=\"11\">#{html.encode(comment).gsub(/\n/,'<br />')}</font>"
          end
          
          if dn
            edge[:label] = "<<font face=\"Verdana\">#{guard} #{action}#{comment}</font>>"
          else
            edge[:label] = "<<font face=\"Verdana\">#{guard}<font face=\"Verdana-Bold\"> #{html.encode(ev.name)} </font> #{action}#{comment}</font>>"
          end
          
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
            callback_code << line_code.strip + "\n  "
          end
        end
        
        return callback_code
      end
    end
  end
end