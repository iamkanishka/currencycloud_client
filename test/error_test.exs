defmodule CurrencycloudClient.ErrorTest do
  use ExUnit.Case, async: true

  alias CurrencycloudClient.Error

  alias CurrencycloudClient.Error.{
    AuthenticationError,
    BadRequestError,
    ForbiddenError,
    InternalServerError,
    NetworkError,
    NotFoundError,
    TooManyRequestsError,
    UnexpectedError
  }

  @req_info %{verb: "POST", url: "https://example.com/v2/payments/create", params: %{}}

  defp make_response(status, body \\ %{}, headers \\ []) do
    %{status: status, body: body, headers: headers}
  end

  describe "from_response/2" do
    test "maps 401 to AuthenticationError" do
      err = Error.from_response(@req_info, make_response(401))
      assert %AuthenticationError{} = err
      assert err.response.status_code == 401
    end

    test "maps 403 to ForbiddenError" do
      err = Error.from_response(@req_info, make_response(403))
      assert %ForbiddenError{} = err
    end

    test "maps 400 to BadRequestError with field errors" do
      body = %{
        "error_messages" => %{
          "currency" => [
            %{"code" => "currency_is_in_invalid_format", "message" => "Invalid", "params" => %{}}
          ]
        }
      }

      err = Error.from_response(@req_info, make_response(400, body))
      assert %BadRequestError{} = err
      assert length(err.errors) == 1
      assert hd(err.errors)["field"] == "currency"
      assert hd(err.errors)["code"] == "currency_is_in_invalid_format"
    end

    test "maps 404 to NotFoundError" do
      err = Error.from_response(@req_info, make_response(404))
      assert %NotFoundError{} = err
    end

    test "maps 429 to TooManyRequestsError with retry_after" do
      headers = [{"retry-after", "30"}]
      err = Error.from_response(@req_info, make_response(429, %{}, headers))
      assert %TooManyRequestsError{retry_after: 30} = err
    end

    test "maps 429 with default retry_after when header absent" do
      err = Error.from_response(@req_info, make_response(429))
      assert %TooManyRequestsError{retry_after: 60} = err
    end

    test "maps 500 to InternalServerError" do
      err = Error.from_response(@req_info, make_response(500))
      assert %InternalServerError{} = err
    end

    test "maps 503 to InternalServerError" do
      err = Error.from_response(@req_info, make_response(503))
      assert %InternalServerError{} = err
    end

    test "maps unknown status to UnexpectedError" do
      err = Error.from_response(@req_info, make_response(418))
      assert %UnexpectedError{} = err
    end

    test "captures request_id from response headers" do
      headers = [{"x-request-id", "req-123"}]
      err = Error.from_response(@req_info, make_response(400, %{}, headers))
      assert err.response.request_id == "req-123"
    end
  end

  describe "from_exception/1" do
    test "creates NetworkError from a map-like exception with reason" do
      exception = %RuntimeError{message: "timeout"}
      err = Error.from_exception(exception)
      assert %NetworkError{} = err
    end

    test "creates NetworkError from bare atom" do
      err = Error.from_exception(:econnrefused)
      assert %NetworkError{reason: :econnrefused} = err
    end
  end

  describe "message/1" do
    test "returns short summary for BadRequestError with field errors" do
      body = %{
        "error_messages" => %{
          "amount" => [
            %{"code" => "required", "message" => "Amount is required", "params" => %{}}
          ]
        }
      }

      err = Error.from_response(@req_info, make_response(400, body))
      msg = Error.message(err)
      assert String.contains?(msg, "BadRequestError")
      assert String.contains?(msg, "Amount is required")
    end

    test "returns summary for NetworkError" do
      err = %NetworkError{reason: :timeout, message: "Request timed out"}
      assert Error.message(err) == "Request timed out"
    end
  end

  describe "to_diagnostic/1" do
    test "returns a YAML-like diagnostic string for BadRequestError" do
      body = %{
        "error_messages" => %{
          "currency" => [%{"code" => "invalid", "message" => "Invalid currency", "params" => %{}}]
        }
      }

      err = Error.from_response(@req_info, make_response(400, body))
      diag = Error.to_diagnostic(err)

      assert String.contains?(diag, "BadRequestError")
      assert String.contains?(diag, "POST")
      assert String.contains?(diag, "currency")
      assert String.contains?(diag, "invalid")
    end

    test "returns diagnostic for NetworkError" do
      err = %NetworkError{reason: :econnrefused, message: "Connection refused"}
      diag = Error.to_diagnostic(err)
      assert String.contains?(diag, "NetworkError")
      assert String.contains?(diag, "econnrefused")
    end
  end
end
