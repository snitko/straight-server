jQuery(function($) {

  $("#create_order").click(function() {
    $.ajax({
      url: '/gateways/1/orders',
      type: 'POST',
      dataType: 'json',
      data: { amount: 1 },
      success: function(response) {
        window.location = '/pay/' + response.payment_id
      }
    });
  });

});
