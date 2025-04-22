"""Tests for the proxy functionality."""

import os

import requests
import xmltodict
from test_utils import print_debug_info, print_request_debug, verify_headers


def test_proxy_health(proxy_url):
    """Test that proxy is up and responding."""
    response = requests.get(f"{proxy_url}/")
    if response.status_code != 200:
        print_debug_info(response)
    assert response.status_code == 200
    assert "Welcome to Wenrix Proxy" in response.text


def test_ba_request(proxy_url):
    """Test that BA proxy correctly handles the request."""
    test_headers = {
        "x-wenrix-operation": "should-be-removed",
        "x-wenrix-trace-id": "should-be-removed",
        "authorization": "should-be-removed",
        "test-header": "should-remain",
    }

    response = requests.get(f"{proxy_url}/channel/britishairways/anything", headers=test_headers)
    if response.status_code != 200:
        print_debug_info(response)
    assert response.status_code == 200

    # httpbin /anything endpoint returns details about the request it received
    request_info = response.json()
    received_headers = request_info["headers"]

    # Verify headers were properly handled
    verify_headers(
        received_headers,
        expected_present={"Test-Header": "should-remain", "Client-Key": "test-ba-key"},
        expected_absent=["X-Wenrix-Operation", "X-Wenrix-Trace-Id", "Authorization"],
    )

    # Verify the URL path was properly forwarded
    assert request_info["url"].endswith("/anything")


def test_farelogix_aa_request(proxy_url):
    """Test that Farelogix AA proxy correctly handles the request."""
    test_body = {
        "username": "#FLX_USERNAME#",
        "password": "#FLX_PASSWORD#",
        "agent": "#FLX_AGENT#",
        "agentUser": "#FLX_AGENT_USER#",
        "agentPassword": "#FLX_AGENT_PASSWORD#",
        "otherField": "unchanged",
    }

    request_headers = {"test-header": "should-remain"}

    base_path = "/channel/farelogix-aa"
    if os.getenv("WP_CHANNELS_FARELOGIX_USE_ACCOUNT_IDS", "").lower() == "true":
        base_path = f"{base_path}/cad"

    response = requests.post(f"{proxy_url}{base_path}/anything", json=test_body, headers=request_headers)
    if response.status_code != 200:
        print_request_debug(response, test_body, request_headers)
    assert response.status_code == 200

    # Get request details from httpbin
    request_info = response.json()

    # Verify headers
    verify_headers(
        request_info["headers"],
        expected_present={"Test-Header": "should-remain", "Ocp-Apim-Subscription-Key": "test-aa-key"},
        expected_absent=[],
    )

    # Verify body transformations
    received_body = request_info["json"]
    assert received_body["username"] == "test-user"
    assert received_body["password"] == "test-pass"
    assert received_body["agent"] == "test-agent"
    assert received_body["agentUser"] == "test-agent-user"
    assert received_body["agentPassword"] == "test-agent-pass"
    assert received_body["otherField"] == "unchanged"  # Verify unchanged fields

    # Verify URL path
    assert request_info["url"].endswith("/anything")


def test_travelfusion_request(proxy_url):
    """Test that Travelfusion proxy correctly handles the request."""
    test_headers = {
        "x-wenrix-operation": "should-be-removed",
        "x-wenrix-trace-id": "should-be-removed",
        "x-wenrix-iata-number": "test-iata",
        "x-wenrix-supplier": "test-supplier",
        "test-header": "should-remain",
    }

    # Sample XML request with placeholders
    test_body = """<?xml version="1.0" encoding="UTF-8"?>
    <Request>
        <LoginId>PLACEHOLDER</LoginId>
        <XmlLoginId>PLACEHOLDER</XmlLoginId>
        <CustomSupplierParameterList>PLACEHOLDER</CustomSupplierParameterList>
        <OtherField>unchanged</OtherField>
    </Request>
    """

    # Use just the base endpoint without /anything
    response = requests.post(f"{proxy_url}/channel/travelfusion/anything", data=test_body, headers=test_headers)
    if response.status_code != 200:
        print_request_debug(response, test_body, test_headers)
    assert response.status_code == 200

    # Get request details from httpbin
    request_info = response.json()

    # Verify headers
    verify_headers(
        request_info["headers"],
        expected_present={"Test-Header": "should-remain", "Content-Type": "text/xml"},
        expected_absent=[
            "X-Wenrix-Operation",
            "X-Wenrix-Trace-Id",
            "X-Wenrix-Iata-Number",
            "X-Wenrix-Supplier",
            "Authorization",
        ],
    )

    # Verify body transformations
    parsed_body = xmltodict.parse(request_info["data"])  # Parse the XML using xmltodict

    assert parsed_body["Request"]["LoginId"] == "test-login", "LoginId replacement did not occur as expected."
    assert parsed_body["Request"]["XmlLoginId"] == "test-login", "XmlLoginId replacement did not occur as expected."
    assert parsed_body["Request"]["OtherField"] == "unchanged", "OtherField value changed unexpectedly."

    supplier_param = parsed_body["Request"]["CustomSupplierParameterList"]["CustomSupplierParameter"]
    assert supplier_param == {
        "Name": "test-login-key",
        "Supplier": "test-supplier",
        "Value": "test-login-value",
    }, f"Supplier parameter list transformation did not occur as expected {parsed_body}"

    # Verify URL path
    assert request_info["url"].endswith("/anything")


def test_travelfusion_request_normal_path(proxy_url):
    """Test that Travelfusion proxy correctly handles the request."""
    test_headers = {"x-wenrix-operation": "should-be-removed", "x-wenrix-trace-id": "should-be-removed"}

    # Sample XML request with placeholders
    test_body = """<?xml version="1.0" encoding="UTF-8"?>
    <Request>
        <LoginId>PLACEHOLDER</LoginId>
        <XmlLoginId>PLACEHOLDER</XmlLoginId>
        <CustomSupplierParameterList>PLACEHOLDER</CustomSupplierParameterList>
        <OtherField>unchanged</OtherField>
    </Request>
    """

    # Use just the base endpoint without /anything
    response = requests.get(f"{proxy_url}/channel/travelfusion", data=test_body, headers=test_headers)

    print_debug_info(response)
    assert response.status_code == 200
