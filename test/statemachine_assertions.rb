module StatemachineAssertions
  def assert_equal_arrays(arr1, arr2)
    assert_equal [], arr1 - arr2, "array #{arr1} is not equal to array #{arr2}"
  end

  def assert_transition_on_event(statemachine, event, from_state, to_state)
    from_state = statemachine.states[from_state]
    to_state   = statemachine.states[to_state]
    event      = statemachine.events[event]

    assert_not_nil from_state
    assert_not_nil to_state
    assert_not_nil event

    failure_msg =  "#{statemachine} does not have a transition from #{from_state.name.inspect} to #{to_state.name.inspect} on event #{event.name.inspect}"
    failure_msg << "\n\tHas: #{from_state.transitions_on_event[event].collect{|tr| tr.to_s}.join("\n")}"


    assert from_state.transitions_on_event[event].any?{|tr| tr.from == from_state && tr.to == to_state}, failure_msg
  end

  def assert_no_transition_on_event(statemachine, event, from_state, to_state)
    from_state = statemachine.states[from_state]
    to_state   = statemachine.states[to_state]
    event      = statemachine.events[event]

    assert_not_nil from_state
    assert_not_nil to_state
    assert_not_nil event

    failure_msg =  "#{statemachine} should not have a transition from #{from_state.name.inspect} to #{to_state.name.inspect} on event #{event.name.inspect}"

    assert !from_state.transitions_on_event[event].any?{|tr| tr.from == from_state && tr.to == to_state}, failure_msg
  end

  def assert_transition_on_event_has_callback(statemachine, event, from_state, to_state, callback, callback_method = nil)
    from_state = statemachine.states[from_state]
    to_state   = statemachine.states[to_state]
    event      = statemachine.events[event]

    assert_transition_on_event(statemachine, event, from_state, to_state)

    tr = from_state.transitions_on_event[event].find{|tr| tr.to == to_state}

    failure_msg =  "#{tr.to_s.inspect} does not have an #{callback.inspect} callback"

    assert_not_nil tr.callbacks[callback], failure_msg

    assert_equal callback_method, tr.callbacks[callback].callback if callback_method
  end

  def assert_transition_on_event_has_guard(statemachine, event, from_state, to_state, guard)
    from_state = statemachine.states[from_state]
    to_state   = statemachine.states[to_state]
    event      = statemachine.events[event]

    assert_transition_on_event(statemachine, event, from_state, to_state)

    tr = from_state.transitions_on_event[event].find{|tr| tr.to == to_state}

    failure_msg =  "#{tr.to_s.inspect} does not have #{guard.inspect} as a guard condition"

    assert tr.guards.collect{|g| g.callback}.include?(guard), failure_msg
  end

  def assert_transition_on_event_does_not_have_guard(statemachine, event, from_state, to_state, guard)
    from_state = statemachine.states[from_state]
    to_state   = statemachine.states[to_state]
    event      = statemachine.events[event]

    assert_transition_on_event(statemachine, event, from_state, to_state)

    tr = from_state.transitions_on_event[event].find{|tr| tr.to == to_state}

    failure_msg =  "#{tr.to_s.inspect} should not have #{guard.inspect} as a guard condition"

    assert !tr.guards.collect{|g| g.callback}.include?(guard), failure_msg
  end
end
