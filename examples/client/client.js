jQuery(function($) {

  $("#create_order").click(function() {
    $.ajax({
      url: '/gateways/' + $("input[name=gateway_id]").val() + '/orders',
      type: 'POST',
      dataType: 'json',
      data: { amount: $("input[name=amount]").val(), signature: $("input[name=signature]").val(), keychain_id :$("input[name=keychain_id]").val() },
      success: function(response) {
        window.location = '/pay/' + response.payment_id
      }
    });
  });

});
