require 'thread'
begin
  # Rubinius
  require 'actor'
  require 'girl_friday/monkey_patches'
rescue LoadError
  # Others
  require 'girl_friday/actor'
end

require 'girl_friday/version'
require 'girl_friday/work_queue'
require 'girl_friday/error_handler'
require 'girl_friday/persistence'
require 'girl_friday/batch'

module GirlFriday

  def self.queues
    ObjectSpace.each_object(GirlFriday::WorkQueue).to_a
  end

  def self.status
    queues.inject({}) { |memo, queue| memo.merge(queue.status) }
  end

  ##
  # Notify girl_friday to shutdown ASAP.  Workers will not pick up any
  # new work; any new work pushed onto the queues will be pushed onto the
  # backlog (and persisted).  This method will block until all queues are
  # quiet or the timeout has passed.
  #
  # Note that shutdown! just works with existing queues.  If you create a
  # new queue, it will act as normal.
  def self.shutdown!(timeout=30)
    qs = queues
    count = qs.size

    if count > 0
      m = Mutex.new
      var = ConditionVariable.new

      qs.each do |q|
        q.shutdown do |queue|
          m.synchronize do
            count -= 1
            var.signal if count == 0
          end
        end
      end

      m.synchronize do
        var.wait(m, timeout)
      end
      #puts "girl_friday shutdown complete"
    end
    count
  end

end

begin
  ObjectSpace.each_object(GirlFriday).to_a
  at_exit do
    GirlFriday.shutdown!
  end
rescue RuntimeError
  $stderr.puts "[warn] girl_friday will not shut down cleanly, pass -X+O to JRuby to enable ObjectSpace"
end

