class ApiController < ActionController::API
  rescue_from ActionController::ParameterMissing do |error|
    render_error_for_exception(error, 422)
  end

  rescue_from Services::Errors::Base do |error|
    render_error(
      error.class.to_s.demodulize.underscore,
      error.message,
      error.status
    )
  end

  protected

  def build_error_payload(code, message)
    {
      code: code,
      message: message
    }
  end

  def render_error(code, message, status)
    render json: build_error_payload(code, message), status: status
  end

  def render_error_for_exception(error, status)
    render_error(
      error.class.to_s.demodulize.underscore,
      error.message,
      status
    )
  end
end
