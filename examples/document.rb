$: << File.expand_path(File.dirname(__FILE__)+"/../lib")
require 'golem'

class Document
  
  def initialize
    @has_signature = false
  end

  def sign!
    @has_signature = true
  end

  def has_signature?
    @has_signature
  end

  include Golem
  define_statemachine do
    initial_state :NEW

    state :NEW do
      on :submit, :to => :SUBMITTED
    end

    state :SUBMITTED do
      on :review do
        transition :to => :APPROVED, :if => :has_signature?
        transition :to => :REJECTED
      end
    end

    state :REJECTED do
      on :revise, :to => :REVISED
    end

    state :REVISED do
      on :submit, :to => :SUBMITTED
    end

    state :APPROVED
  end
end

