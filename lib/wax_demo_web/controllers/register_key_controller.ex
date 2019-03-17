defmodule WaxDemoWeb.RegisterKeyController do
  use WaxDemoWeb, :controller

  require Logger

  def index(conn, _params) do
    case get_session(conn, :login) do
      login when is_binary(login) ->
        challenge = Wax.new_registration_challenge([])

        Logger.debug("Wax: generated attestation challenge #{inspect(challenge)}")

        conn
        |> put_session(:challenge, challenge)
        |> render("register_key.html",
          login: get_session(conn, :login),
          challenge: Base.encode64(challenge.bytes),
          rp_id: challenge.rp_id,
          user: login
        )

      nil ->
        redirect(conn, to: "/")
    end
  end

  def validate(conn, %{
        "key" => %{
          "attestationObject" => attestation_object_b64,
          "clientDataJSON" => client_data_json,
          "rawID" => raw_id_b64,
          "type" => "public-key"
        }
      }) do
    challenge = get_session(conn, :challenge)

    attestation_object = Base.decode64!(attestation_object_b64)

    case Wax.register(attestation_object, client_data_json, challenge) do
      {:ok, {cose_key, attestation_result, auth_data}} ->
        Logger.debug(
          "Wax: attestation object validated with cose key #{inspect(cose_key)} " <>
            " and attestation result #{inspect(attestation_result)}"
        )

        # auth_data.flag_user_present
        # if auth_data.flag_user_verified
        
        user = get_session(conn, :login)

        WaxDemo.User.register_new_cose_key(user, raw_id_b64, cose_key)

        conn
        |> put_flash(:info, "Key registered")
        |> redirect(to: "/me")

      {:error, _} = error ->
        Logger.debug("Wax: attestation object validation failed with error #{inspect(error)}")

        conn
        |> put_flash(:error, "Key registration failed")
        |> index(%{})
    end
  end
end
