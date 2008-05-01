require 'digest/md5'

# Throttle arbituary operation. Once limit is reached it will raise a 
# Throttle::LimitExeeded exception. 
#
# Example: 
#
#   Throttle.for("feed:#{request.remote_ip}", :max => 20, :in => 10.minutes) do
#     render :xml => Articles.all
#   end
#
#   If you want to clear the timeout for the current block ( for example: fraud protection. Clear the throttle when 
#   the submitted Credit Card was valid. ) your block can accept a yielded throttle object and call the clear method
#
#   Throttle.for("cc:#{request.remote_ip}", :max => 20, :in => 10.minutes) do |throttle|
#     if am.pay(@credit_card)        
#       throttle.clear
#       redirect_to :action => 'done'
#     end
#   end
#
class Throttle           
  class LimitExceeded < StandardError
  end
  
  def self.for(key, options = {})     
    throttle = self.new(key, options)    
    if ActionController::Base.perform_caching    
      throttle.increment_counter             
    end
  
    yield throttle
  end  
  
  def initialize(key, options)                            
    @key  =  key.blank? ? nil : "throttle:#{Digest::MD5.hexdigest(key.to_s)}"    
    @max, @timeout = options[:max].to_i, options[:in].to_i
  end            
  
  def increment_counter    
    return if @key.blank?  
    
    count = Rails.cache.increment(@key)

    if count.nil?
      Rails.cache.write @key, 1, :expires_in => @timeout
    elsif @max <= count
      raise LimitExceeded, "Too many requests for operation"
    end
  end
  
  def clear
    return if @key.blank?
    return unless ActionController::Base.perform_caching    
    
    Rails.cache.delete @key
    true
  end                                          
  
end
                                                           
