class Roda
  module RodaPlugins
    # The indifferent_params plugin adds a +params+ instance
    # method which returns a copy of the request params hash
    # that will automatically convert symbols to strings.
    # Example:
    #
    #   plugin :indifferent_params
    #
    #   route do |r|
    #     params[:foo]
    #   end
    #
    # The params hash is initialized lazily, so you only pay
    # the penalty of copying the request params if you call
    # the +params+ method.
    module IndifferentParams
      module InstanceMethods
        # A copy of the request params that will automatically
        # convert symbols to strings.
        def params
          @_params ||= indifferent_params(request.params)
        end

        private

        # Recursively process the request params and convert
        # hashes to support indifferent access, leaving
        # other values alone.
        def indifferent_params(params)
          case params 
          when Hash
            hash = Hash.new{|h, k| h[k.to_s] if Symbol === k}
            params.each{|k, v| hash[k] = indifferent_params(v)}
            hash
          when Array
            params.map{|x| indifferent_params(x)}
          else
            params
          end
        end
      end  
    end

    register_plugin(:indifferent_params, IndifferentParams)
  end
end
