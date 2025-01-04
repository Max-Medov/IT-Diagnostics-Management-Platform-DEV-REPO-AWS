# cert.tf
resource "tls_private_key" "selfsigned_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "selfsigned_cert" {
  subject {
    common_name  = "it-diagnostics.us-east-1.elb.amazonaws.com" 
    organization = "MyOrg"
  }
  validity_period_hours = 8760
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth"
  ]

  private_key_pem = tls_private_key.selfsigned_key.private_key_pem
}

resource "aws_acm_certificate" "selfsigned_acm" {
  certificate_body  = tls_self_signed_cert.selfsigned_cert.cert_pem
  private_key       = tls_private_key.selfsigned_key.private_key_pem
  certificate_chain = tls_self_signed_cert.selfsigned_cert.cert_pem
}

