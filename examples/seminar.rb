$: << File.expand_path(File.dirname(__FILE__)+"/../lib")
require 'golem'


class Seminar
  attr_accessor :status
  attr_accessor :students
  attr_accessor :waiting_list
  attr_accessor :max_class_size
  attr_accessor :notifications_sent

  @@out = STDOUT

  def self.output=(output)
    @@out = output
  end

  def initialize
    @students = [] # list of students enrolled in the course
    @max_class_size = 5
    @notifications_sent = []
  end

  def seats_available
    @max_class_size - @students.size
  end

  def waiting_list_is_empty?
    @waiting_list.empty?
  end

  def student_is_enrolled?(student)
    @students.include? student
  end

  def add_student_to_waiting_list(student)
    @waiting_list << student
  end

  def create_waiting_list
    @waiting_list = []
  end

  def notify_waiting_list_that_enrollment_is_closed
    @waiting_list.each{|student| self.notifications_sent << "#{student}: waiting list is closed"}
  end

  def notify_students_that_the_seminar_is_cancelled
    (@students + @waiting_list).each{|student| self.notifications_sent << "#{student}: the seminar has been cancelled"}
  end  


  include Golem

  define_statemachine do
    initial_state :proposed
    state_attribute :status

    state :proposed do
      on :schedule, :to => :scheduled
    end

    state :scheduled do
      on :open, :to => :open_for_enrollment
    end

    state :open_for_enrollment do
      on :close, :to => :closed_to_enrollment
      on :enroll_student do
        transition do
          guard {|seminar, student| !seminar.student_is_enrolled?(student) && seminar.seats_available > 1 }
          action {|seminar, student| seminar.students << student}
        end
        transition :to => :full do
          guard {|seminar, student| !seminar.student_is_enrolled?(student) }
          action do |seminar, student|
            seminar.create_waiting_list
            if seminar.seats_available == 1
              seminar.students << student
            else
              seminar.add_student_to_waiting_list(student)
            end
          end
        end
      end
      on :drop_student do
        transition :if => :student_is_enrolled? do
          action {|seminar, student| seminar.students.delete student}
        end
      end
    end

    state :full do
      on :move_to_bigger_classroom, :to => :open_for_enrollment,
        :action => Proc.new{|seminar, additional_seats| seminar.max_class_size += additional_seats}
      # Note that this :if condition applies to all transitions inside the event, in addition to each
      # transaction's own :if/guard statement.
      on :drop_student, :if => :student_is_enrolled? do
        transition :to => :open_for_enrollment, :if => :waiting_list_is_empty? do
          action {|seminar, student| seminar.students.delete student}
        end
        transition do
          action do |seminar, student|
            seminar.students.delete student
            seminar.enroll_student seminar.waiting_list.shift
          end
        end
      end
      on :enroll_student, :if => Proc.new{|seminar, student| !seminar.student_is_enrolled?(student)} do
        transition do
          guard {|seminar, student| seminar.seats_available > 0}
          action {|seminar, student| seminar.students << student}
        end
        transition :action => :add_student_to_waiting_list
      end
      on :close, :to => :closed_to_enrollment
    end

    state :closed_to_enrollment do
      enter :notify_waiting_list_that_enrollment_is_closed
    end

    state :cancelled do
      enter :notify_students_that_the_seminar_is_cancelled
    end

    # The 'cancel' event can occur in all states.
    all_states.each do |state|
      state.on :cancel, :to => :cancelled
    end

    on_all_transitions do |seminar, event, transition, *event_args|
      @@out.puts "==[#{event.name}(#{event_args.collect{|arg| arg.inspect}.join(",")})]==>  #{transition.from.name} --> #{transition.to.name}"
      @@out.puts "   ENROLLED: #{seminar.students.inspect}"
      @@out.puts "   WAITING: #{seminar.waiting_list.inspect}"
    end
  end
end