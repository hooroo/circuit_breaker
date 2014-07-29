# encoding: utf-8
module CircuitBreaker
  class RedisFailureState
    def initialize(mixee)
      @mixee = mixee
    end

    def last_failure_time_key
      "circuit_breaker-#{@mixee}-last_failure_time"
    end

    def failure_count_key
      "circuit_breaker-#{@mixee}-failure_count"
    end

    def last_failure_time
      handle_timeout(1.year.from_now) do
        Time.at(redis.get(last_failure_time_key).to_f)
      end
    end

    def last_failure_time=(value)
      handle_timeout do
        redis.set(last_failure_time_key, value.to_s)
      end
    end

    def failure_count
      handle_timeout(0) do
        redis.get(failure_count_key).to_i #nil.to_i == 0
      end
    end

    def failure_count=(value)
      handle_timeout do
        redis.set(failure_count_key, value)
      end
    end

    def increment_failure_count
      handle_timeout do
        redis.multi do |multi|
          multi.incr(failure_count_key)
          multi.set(last_failure_time_key, Time.now.to_f)
        end
      end
    end

    def reset_failure_count
      handle_timeout do
        redis.set(failure_count_key, 0)
      end
    end

    def redis
      fail ArgumentError, 'RedisFailureState needs a Redis instance' unless self.class.redis
      self.class.redis
    end

    class << self
      attr_accessor :redis
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
