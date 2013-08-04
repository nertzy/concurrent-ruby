require 'thread'

module Concurrent

  module Executor
    extend self

    class ExecutionContext
      attr_reader :name
      attr_reader :execution_interval
      attr_reader :timeout_interval

      def initialize(name, execution_interval, timeout_interval, thread)
        @name = name
        @execution_interval = execution_interval
        @timeout_interval = timeout_interval
        @thread = thread
        @thread[:stop] = false
      end

      def status
        return @thread.status unless @thread.nil?
      end

      def join(limit = nil)
        if @thread.nil?
          return nil
        elsif limit.nil?
          return @thread.join
        else
          return @thread.join(limit)
        end
      end

      def kill
        @thread[:stop] = true
      end
      alias_method :terminate, :kill
      alias_method :stop, :kill
    end

    EXECUTION_INTERVAL = 60
    TIMEOUT_INTERVAL = 30

    STDOUT_LOGGER = proc do |name, level, msg|
      print "%5s (%s) %s: %s\n" % [level.upcase, Time.now.strftime("%F %T"), name, msg]
    end

    def run(name, opts = {})
      raise ArgumentError.new('no block given') unless block_given?

      execution_interval = opts[:execution] || opts[:execution_interval] || EXECUTION_INTERVAL
      timeout_interval = opts[:timeout] || opts[:timeout_interval] || TIMEOUT_INTERVAL
      logger = opts[:logger] || STDOUT_LOGGER
      block_args = opts[:args] || opts [:arguments] || []

      executor = Thread.new(*block_args) do |*args|
        loop do
          sleep(execution_interval)
          break if Thread.current[:stop]
          begin
            worker = Thread.new{ yield(*args) }
            worker.abort_on_exception = false
            if worker.join(timeout_interval).nil?
              logger.call(name, :warn, "execution timed out after #{timeout_interval} seconds")
            else
              logger.call(name, :info, 'execution completed successfully')
            end
          rescue Exception => ex
            logger.call(name, :error, "execution failed with error '#{ex}'")
          ensure
            Thread.kill(worker)
            worker = nil
          end
          break if Thread.current[:stop]
        end
      end

      return ExecutionContext.new(name, execution_interval, timeout_interval, executor)
    end
  end
end