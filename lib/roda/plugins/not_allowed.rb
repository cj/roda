class Roda
  module RodaPlugins
    # The not_allowed plugin makes Roda attempt to automatically
    # support the 405 Method Not Allowed response status. The plugin
    # changes the +r.get+ and +r.post+ verb methods to automatically
    # return a 405 status if they are called with any arguments, and
    # the arguments match but the request method does not match. So
    # this code:
    #
    #   r.get '' do
    #     "a"
    #   end
    #
    # will return a 200 response for <tt>GET /</tt> and a 405
    # response for <tt>POST /</tt>.
    #
    # This plugin also changes the +r.is+ method so that if you use
    # a verb method inside +r.is+, it returns a 405 status if none
    # of the verb methods match.  So this code:
    #
    #   r.is '' do
    #     r.get do
    #       "a"
    #     end
    #
    #     r.post do
    #       "b"
    #     end
    #   end
    #
    # will return a 200 response for <tt>GET /</tt> and <tt>POST /</tt>,
    # but a 405 response for <tt>PUT /</tt>.
    #
    # Note that this plugin will probably not do what you want for
    # code such as:
    #
    #   r.get '' do
    #     "a"
    #   end
    #
    #   r.post '' do
    #     "b"
    #   end
    #
    # Since for a <tt>POST /</tt> request, when +r.get+ method matches
    # the path but not the request method, it will return an immediate
    # 405 response.  You must DRY up this code for it work correctly,
    # like this:
    #
    #   r.is '' do
    #     r.get do
    #       "a"
    #     end
    #
    #     r.post do
    #       "b"
    #     end
    #   end
    #
    # In all cases where it uses a 405 response, it also sets the +Allow+
    # header in the response to contain the request methods supported.
    # 
    # To make this affect the verb methods added by the all_verbs plugin,
    # load this plugin first.
    module NotAllowed
      # Redefine the +r.get+ and +r.post+ methods when loading the plugin.
      def self.configure(app)
        app.request_module do
          app::RodaRequest.def_verb_method(self, :get)
          app::RodaRequest.def_verb_method(self, :post)
        end
      end

      module RequestClassMethods
        # Define a method named +verb+ in the given module which will
        # return a 405 response if the method is called with any
        # arguments and the arguments terminally match but the
        # request method does not.
        #
        # If called without any arguments, check to see if the call
        # is inside a terminal match, and in that case record the
        # request method used.
        def def_verb_method(mod, verb)
          mod.class_eval(<<-END, __FILE__, __LINE__+1)
            def #{verb}(*args, &block)
              if args.empty?
                @_is_verbs << "#{verb.to_s.upcase}" if defined?(@_is_verbs)
                always(&block) if #{verb == :get ? :is_get : verb}?
              else
                args << ::Roda::RodaPlugins::Base::RequestMethods::TERM
                if_match(args) do |*a|
                  if #{verb == :get ? :is_get : verb}?
                    block_result(yield(*a))
                    throw :halt, response.finish
                  end
                  response.status = 405
                  response['Allow'] = '#{verb.to_s.upcase}'
                  nil
                end
              end
            end
          END
        end
      end

      module RequestMethods
        # Keep track of verb calls inside the block.  If there are any
        # verb calls inside the block, but the block returned, assume
        # that the verb calls inside the block did not match, and
        # since there was already a successful terminal match, the
        # request method must not be allowed, so return a 405
        # response in that case.
        def is(*verbs)
          super(*verbs) do
            begin
              @_is_verbs = []

              ret = if verbs.empty?
                yield
              else
                yield(*captures)
              end

              unless @_is_verbs.empty?
                response.status = 405
                response['Allow'] = @_is_verbs.join(', ')
              end

              ret
            ensure
              @_is_verbs = nil
            end
          end
        end
      end
    end

    register_plugin(:not_allowed, NotAllowed)
  end
end
