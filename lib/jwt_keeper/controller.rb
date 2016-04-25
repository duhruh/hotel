module JWTKeeper
  module Controller
    def self.included(klass)
      klass.class_eval do
        include InstanceMethods
      end
    end

    module InstanceMethods
      # Available to be used as a before_action by the application's controllers. This is
      # the main logical section for decoding, and automatically rotating tokens
      def require_authentication
        token = read_authentication_token
        return not_authenticated if token.nil?

        if token.version_mismatch? || token.pending?
          new_claims = regenerate_claims(token)
          token.rotate(new_claims)
        end

        write_authentication_token(token)
        authenticated(token)
      end

      # Decodes and returns the token
      def read_authentication_token
        return nil unless request.headers['Authorization']
        @authentication_token ||=
          JWTKeeper::Token.find(request.headers['Authorization'].split.last, cookies['jwt_keeper'])
      end

      # Encodes and writes the token
      def write_authentication_token(token)
        return clear_authentication_token if token.nil?
        response.headers['Authorization'] = "Bearer #{token.to_jwt}"
        cookies['jwt_keeper'] = token.to_cookie
        @authentication_token = token
      end

      # delets the authentication token
      def clear_authentication_token
        response.headers['Authorization'] = nil
        cookies.delete('jwt_keeper')
        @authentication_token = nil
      end

      # Used when a user tries to access a page while logged out, is asked to login,
      # and we want to return him back to the page he originally wanted.
      def redirect_back_or_to(url, flash_hash = {})
        redirect_to(session[:return_to_url] || url, flash: flash_hash)
        session[:return_to_url] = nil
      end

      # The default action for denying non-authenticated connections.
      # You can override this method in your controllers
      def not_authenticated
        redirect_to root_path
      end

      # The default action for accepting authenticated connections.
      # You can override this method in your controllers
      def authenticated(token)
      end

      # Invoked by the require_authentication method as part of the automatic rotation
      # process. The application should override this method to include the necessary
      # claims.
      def regenerate_claims(old_token)
      end
    end
  end
end
