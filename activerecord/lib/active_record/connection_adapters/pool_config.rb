# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class PoolConfig # :nodoc:
      include Mutex_m

      attr_reader :db_config, :connection_klass
      attr_accessor :schema_cache

      INSTANCES = ObjectSpace::WeakMap.new
      private_constant :INSTANCES

      class << self
        def discard_pools!
          INSTANCES.each_key(&:discard_pool!)
        end
      end

      def initialize(connection_klass, db_config)
        puts "[PoolConfig] Initializing super method"
        super()
        puts "[PoolConfig] Initializing PoolConfig" # with connection_klass: #{connection_klass.inspect} and db_config:" # #{db_config.inspect}"

        @connection_klass = connection_klass
        @db_config = db_config
        @pool = nil
        INSTANCES[self] = self
      end

      def connection_specification_name
        if connection_klass.is_a?(String)
          connection_klass
        elsif connection_klass.primary_class?
          "ActiveRecord::Base"
        else
          connection_klass.name
        end
      end

      def disconnect!
        ActiveSupport::ForkTracker.check!

        return unless @pool

        synchronize do
          return unless @pool

          @pool.automatic_reconnect = false
          @pool.disconnect!
        end

        nil
      end

      def pool
        ActiveSupport::ForkTracker.check!

        @pool || synchronize { @pool ||= ConnectionAdapters::ConnectionPool.new(self) }
      end

      def discard_pool!
        return unless @pool

        synchronize do
          return unless @pool

          @pool.discard!
          @pool = nil
        end
      end
    end
  end
end

ActiveSupport::ForkTracker.after_fork { ActiveRecord::ConnectionAdapters::PoolConfig.discard_pools! }
