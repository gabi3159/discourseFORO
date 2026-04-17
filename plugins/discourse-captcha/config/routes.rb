# frozen_string_literal: true

Discourse::Application.routes.draw { mount DiscourseCaptcha::Engine, at: "captcha" }

DiscourseCaptcha::Engine.routes.draw do
  post "/hcaptcha/create" => "hcaptcha#create"
  post "/recaptcha/create" => "recaptcha#create"
end
