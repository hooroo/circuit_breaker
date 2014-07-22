# encoding: utf-8
module CircuitBreaker
  class RedisFailureState
    LAST_FAILURE_TIME = 'last_failure_time'.freeze
    FAILURE_COUNT     = 'failure_count'.freeze

    def last_failure_time
      handle_timeout(1.year.from_now) do
        Time.at(redis.get(LAST_FAILURE_TIME).to_f)
      end
    end

    def last_failure_time=(value)
      handle_timeout do
        redis.set(LAST_FAILURE_TIME, value.to_s)
      end
    end

    def failure_count
      handle_timeout(0) do
        redis.get(FAILURE_COUNT).to_i #nil.to_i == 0
      end
    end

    def failure_count=(value)
      handle_timeout do
        redis.set(FAILURE_COUNT, value)
      end
    end

    def increment_failure_count
      handle_timeout do
        redis.multi do |multi|
          multi.incr(FAILURE_COUNT)
          multi.set(LAST_FAILURE_TIME, Time.now.to_f)
        end
      end
    end

    def reset_failure_count
      handle_timeout do
        redis.set(FAILURE_COUNT, 0)
      end
    end

    def redis
      fail ArgumentError, 'RedisFailureState needs a Redis instance' unless self.class.redis
      puts "@@ RFS: redis=#{self.class.redis}"
      self.class.redis
    end

    def self.redis=(conn)
      puts "@@ RFS: settings redis=#{conn}"
      @redis = conn
    end

    def redis
      @redis
    end

    private
    def handle_timeout(default_return = nil)
      yield
    rescue Redis::TimeoutError => e
      Rails.logger.warn("Redis::TimeoutError in circuit_breaker. Smothering: #{e} #{Logging.to_cleaned_s(e.backtrace)}")
      return default_return
    end
  end
end
