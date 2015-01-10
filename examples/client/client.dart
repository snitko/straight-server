import 'dart:html';
import 'dart:convert';

main() {

  var create_order_button = document.querySelector('button#create_order');

  create_order_button.onClick.listen((e) =>
    create_order().listen((event) {
      var order = JSON.decode(event.target.responseText);

      // Showing full order info that the server has returned us
      // in the console.
      print(order);

      show_pay_order(order);
      listen_to_order(order);
    })
  );

}

create_order() {
  var request  = new HttpRequest();
  var listener = request.onLoad;
  request.open('POST', '/gateways/1/orders?amount=1');
  request.send();
  return listener;
}

listen_to_order(order) {
  var ws = new WebSocket("ws://localhost:9696/gateways/1/orders/${order['id']}/websocket");
  ws.onMessage.listen((MessageEvent e) {
    var order = JSON.decode(e.data);
    if(order['status'] > 1) show_order_paid(order);
  });
}

show_pay_order(order) {
  var new_order_el  = document.querySelector('#newOrder');
  var pay_order_el  = document.querySelector('#payOrder');

  pay_order_el.querySelector('.orderId').text      = order['id'].toString();
  pay_order_el.querySelector('.orderAmount').text  = order['amount'].toString();
  pay_order_el.querySelector('.orderAddress').text = order['address'];

  new_order_el.style.display = 'none';
  pay_order_el.style.display = '';
}

show_order_paid(order) {

  var status;
  if(order['status'] == 2) {
    status = 'PAID';
  } else if(order['status'] == 3) {
    status = 'UNDERPAID';
  } else if(order['status'] == 4) {
    status = 'OVERPAID';
  } else {
    status = order['status'].toString();
  }

  var order_paid_el = document.querySelector('#orderPaid');
  var pay_order_el  = document.querySelector('#payOrder');
  order_paid_el.querySelector('.orderStatus').text = status;
  order_paid_el.querySelector('.orderTid').text    = order['tid'];

  pay_order_el.style.display = 'none';
  order_paid_el.style.display = '';

}
