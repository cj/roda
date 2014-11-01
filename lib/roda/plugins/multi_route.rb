class Roda
  module RodaPlugins
    # The multi_route plugin allows for multiple named routes, which the
    # main route block can dispatch to by name at any point by calling +route+.
    # If the named route doesn't handle the request, execution will continue,
    # and if the named route does handle the request, the response returned by
    # the named route will be returned.
    #
    # In addition, this also adds the +r.multi_route+ method, which will assume
    # check if the first segment in the path matches a named route, and dispatch
    # to that named route.
    #
    # Example:
    #
    #   plugin :multi_route
    #
    #   route('foo') do |r|
    #     r.is 'bar' do
    #       '/foo/bar'
    #     end
    #   end
    #
    #   route('bar') do |r|
    #     r.is 'foo' do
    #       '/bar/foo'
    #     end
    #   end
    #
    #   route do |r|
    #     r.multi_route
    #
    #     # or
    #
    #     r.on "foo" do
    #       r.route 'foo'
    #     end
    #
    #     r.on "bar" do
    #       r.route 'bar'
    #     end
    #   end
    #
    # Note that in multi-threaded code, you should not attempt to add a
    # named route after accepting requests.
    #
    # If you want to use the +r.multi_route+ method, use string names for the
    # named routes.  Also, you can provide a block to +r.multi_route+ that is
    # called if the route matches but the named route did not handle the
    # request:
    #
    #   r.multi_route do
    #     "default body"
    #   end
    # 
    # If a block is not provided to multi_route, the return value of the named
    # route block will be used.
    #
    # ## Namespace Support
    #
    # The multi_route plugin also has support for namespaces, allowing you to
    # use r.multi_route at multiple levels in your routing tree.  Example:
    #
    #   route('foo') do |r|
    #     r.multi_route('foo')
    #   end
    #
    #   route('bar') do |r|
    #     r.multi_route('bar')
    #   end
    #
    #   route('baz', 'foo') do |r|
    #     # handles /foo/baz prefix
    #   end
    #
    #   route('quux', 'foo') do |r|
    #     # handles /foo/quux prefix
    #   end
    #
    #   route('baz', 'bar') do |r|
    #     # handles /bar/baz prefix
    #   end
    #
    #   route('quux', 'bar') do |r|
    #     # handles /bar/quux prefix
    #   end
    #
    #   route do |r|
    #     r.multi_route
    #
    #     # or
    #
    #     r.on "foo" do
    #       r.on("baz"){r.route("baz", "foo")}
    #       r.on("quux"){r.route("quux", "foo")}
    #     end
    #
    #     r.on "bar" do
    #       r.on("baz"){r.route("baz", "bar")}
    #       r.on("quux"){r.route("quux", "bar")}
    #     end
    #   end
    #
    module MultiRoute
      # Initialize storage for the named routes.
      def self.configure(app)
        app.instance_exec do
          @namespaced_routes ||= {}
          app::RodaRequest.instance_variable_set(:@namespaced_route_regexps, {})
        end
      end

      module ClassMethods
        # Copy the named routes into the subclass when inheriting.
        def inherited(subclass)
          super
          nsr = subclass.instance_variable_set(:@namespaced_routes, {})
          @namespaced_routes.each{|k, v| nsr[k] = v.dup}
          subclass::RodaRequest.instance_variable_set(:@namespaced_route_regexps, {})
        end

        # The names for the currently stored named routes
        def named_routes(namespace=nil)
          @namespaced_routes[namespace].keys
        end

        # Return the named route with the given name.
        def named_route(name, namespace=nil)
          @namespaced_routes[namespace][name]
        end

        # If the given route has a name, treat it as a named route and
        # store the route block.  Otherwise, this is the main route, so
        # call super.
        def route(name=nil, namespace=nil, &block)
          if name
            @namespaced_routes[namespace] ||= {}
            @namespaced_routes[namespace][name] = block
            self::RodaRequest.clear_named_route_regexp!(namespace)
          else
            super(&block)
          end
        end
      end

      module RequestClassMethods
        # Clear cached regexp for named routes, it will be regenerated
        # the next time it is needed.
        #
        # This shouldn't be an issue in production applications, but
        # during development it's useful to support new named routes
        # being added while the application is running.
        def clear_named_route_regexp!(namespace=nil)
          @namespaced_route_regexps.delete(namespace)
        end

        # A regexp matching any of the current named routes.
        def named_route_regexp(namespace=nil)
          @namespaced_route_regexps[namespace] ||= /(#{Regexp.union(roda_class.named_routes(namespace).select{|s| s.is_a?(String)}.sort.reverse)})/
        end
      end

      module RequestMethods
        # Check if the first segment in the path matches any of the current
        # named routes.  If so, call that named route.  If not, do nothing.
        # If the named route does not handle the request, and a block
        # is given, yield to the block.
        def multi_route(namespace=nil)
          on self.class.named_route_regexp(namespace) do |section|
            r = route(section, namespace)
            if block_given?
              yield
            else
              r
            end
          end
        end

        # Dispatch to the named route with the given name.
        def route(name, namespace=nil)
          scope.instance_exec(self, &self.class.roda_class.named_route(name, namespace))
        end
      end
    end

    register_plugin(:multi_route, MultiRoute)
  end
end
