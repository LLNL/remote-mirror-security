module SecureMirror
  class ClientGenericError < StandardError; end
  class ClientUnauthorized < ClientGenericError; end
  class ClientForbidden < ClientGenericError; end
  class ClientServerError < ClientGenericError; end
  class ClientNotFound < ClientGenericError; end
end