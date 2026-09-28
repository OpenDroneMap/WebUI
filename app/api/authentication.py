from rest_framework_simplejwt.authentication import JWTAuthentication


class JSONWebTokenAuthenticationQS(JWTAuthentication):
    """
    JWT authentication that accepts the token from the 'jwt' query string
    parameter. Header authentication is handled by JWTAuthentication.
    """
    def authenticate(self, request):
        raw_token = request.query_params.get('jwt')
        if not raw_token:
            return None

        validated_token = self.get_validated_token(raw_token)
        return self.get_user(validated_token), validated_token
