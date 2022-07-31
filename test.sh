#!/usr/bin/env bash

set -e -o pipefail

getInvoices() {
  local url="$1"
  local paid="$2"
  curl -s "${url}/invoices" | jq ".[] | select(.IsPaid==${paid})"
}

main() {
  local url
  url=$(minikube service invoice-app --url)
  echo currently unpaid invoices
  getInvoices "${url}" false
  echo
  echo paying invoices
  curl -s -X POST "${url}/invoices/pay" | jq .
  echo
  echo paid invoices
  getInvoices "${url}" true
  echo
}

main "$@"
