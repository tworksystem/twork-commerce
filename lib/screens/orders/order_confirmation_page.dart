import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ecommerce_int2/providers/cart_provider.dart';
import 'package:ecommerce_int2/providers/order_provider.dart';
import 'package:ecommerce_int2/providers/auth_provider.dart';
import 'package:ecommerce_int2/providers/point_provider.dart';
import 'package:ecommerce_int2/models/order.dart';
import 'package:ecommerce_int2/models/address.dart';
import 'package:ecommerce_int2/models/cart_item.dart';
import 'package:ecommerce_int2/app_properties.dart';
import 'package:ecommerce_int2/screens/orders/order_details_page.dart';
import 'package:ecommerce_int2/screens/main/main_page.dart';
import 'package:ecommerce_int2/utils/logger.dart';
import 'package:ecommerce_int2/services/point_service.dart';

class OrderConfirmationPage extends StatefulWidget {
  final Address? selectedShippingAddress;
  final Address? selectedBillingAddress;
  final PaymentMethod selectedPaymentMethod;
  final int redeemedPoints;
  final double pointsDiscount;

  const OrderConfirmationPage({
    super.key,
    this.selectedShippingAddress,
    this.selectedBillingAddress,
    required this.selectedPaymentMethod,
    this.redeemedPoints = 0,
    this.pointsDiscount = 0.0,
  });

  @override
  _OrderConfirmationPageState createState() => _OrderConfirmationPageState();
}

class _OrderConfirmationPageState extends State<OrderConfirmationPage> {
  bool _isCreatingOrder = false;
  Order? _createdOrder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        iconTheme: IconThemeData(color: darkGrey),
        title: Text(
          'Order Confirmation',
          style: TextStyle(
            color: darkGrey,
            fontWeight: FontWeight.w500,
            fontSize: 18.0,
          ),
        ),
      ),
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          if (cartProvider.isEmpty) {
            return _buildEmptyCartState();
          }

          if (_createdOrder != null) {
            return _buildOrderSuccessState();
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderSummary(cartProvider),
                SizedBox(height: 20),
                _buildAddressSection(),
                SizedBox(height: 20),
                _buildPaymentSection(),
                SizedBox(height: 20),
                _buildOrderItems(cartProvider),
                SizedBox(height: 30),
                _buildPlaceOrderButton(cartProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyCartState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 100,
            color: Colors.grey[300],
          ),
          SizedBox(height: 20),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Add some items to your cart first',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => MainPage()),
              (route) => false,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: mediumYellow,
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            child: Text(
              'Continue Shopping',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSuccessState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                color: Colors.white,
                size: 60,
              ),
            ),
            SizedBox(height: 32),
            Text(
              'Order Placed Successfully!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: darkGrey,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'Your order #${_createdOrder!.id} has been confirmed',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => MainPage()),
                      (route) => false,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      padding: EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: Text(
                      'Continue Shopping',
                      style: TextStyle(
                        color: darkGrey,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderDetailsPage(order: _createdOrder!),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mediumYellow,
                      padding: EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: Text(
                      'View Order',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(CartProvider cartProvider) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [mediumYellow, mediumYellow.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: mediumYellow.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Items (${cartProvider.itemCount})',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              Text(
                cartProvider.formattedTotalPrice,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shipping',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              Text(
                '\$0.00',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tax',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              Text(
                '\$0.00',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          if (widget.pointsDiscount > 0) ...[
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.stars,
                      size: 16,
                      color: Colors.white70,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Points Discount',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Text(
                  '-\$${widget.pointsDiscount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.green[200],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
          Divider(color: Colors.white70),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '\$${(cartProvider.totalPrice - widget.pointsDiscount).toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: mediumYellow, size: 20),
                SizedBox(width: 8),
                Text(
                  'Delivery Address',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkGrey,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (widget.selectedShippingAddress != null)
              _buildAddressInfo(widget.selectedShippingAddress!)
            else
              Text(
                'No address selected',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressInfo(Address address) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${address.firstName} ${address.lastName}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: darkGrey,
          ),
        ),
        SizedBox(height: 4),
        Text(
          address.completeAddress,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 4),
        Text(
          '${address.city}, ${address.state} ${address.postalCode}',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 4),
        Text(
          address.phone,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payment, color: mediumYellow, size: 20),
                SizedBox(width: 8),
                Text(
                  'Payment Method',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkGrey,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              _getPaymentMethodText(widget.selectedPaymentMethod),
              style: TextStyle(
                fontSize: 16,
                color: darkGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItems(CartProvider cartProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkGrey,
              ),
            ),
            SizedBox(height: 12),
            ...cartProvider.items.map((item) => _buildOrderItem(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(CartItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[200],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                item.product.image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.image,
                    color: Colors.grey,
                  );
                },
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: darkGrey,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  'Qty: ${item.quantity}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            item.formattedTotalPrice,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: mediumYellow,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceOrderButton(CartProvider cartProvider) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isCreatingOrder ? null : () => _placeOrder(cartProvider),
        style: ElevatedButton.styleFrom(
          backgroundColor: mediumYellow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: _isCreatingOrder
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Creating Order...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : Text(
                'Place Order',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Future<void> _placeOrder(CartProvider cartProvider) async {
    if (widget.selectedShippingAddress == null) {
      _showErrorSnackBar('Please select a shipping address');
      return;
    }

    setState(() {
      _isCreatingOrder = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);

      if (!authProvider.isAuthenticated) {
        _showErrorSnackBar('Please login to place an order');
        return;
      }

      // Enhanced debugging and validation
      Logger.debug('Starting order creation process...', tag: 'OrderConfirmation');
      Logger.debug('User ID: ${authProvider.user!.id}', tag: 'OrderConfirmation');
      Logger.debug('Cart Items: ${cartProvider.items.length}', tag: 'OrderConfirmation');
      Logger.debug(
          'Shipping Address: ${widget.selectedShippingAddress!.firstName} ${widget.selectedShippingAddress!.lastName}',
          tag: 'OrderConfirmation');
      Logger.debug('Payment Method: ${widget.selectedPaymentMethod.name}',
          tag: 'OrderConfirmation');

      // Validate cart items
      if (cartProvider.items.isEmpty) {
        _showErrorSnackBar('Your cart is empty. Please add items to cart.');
        return;
      }

      // Validate addresses
      if (widget.selectedShippingAddress!.firstName.isEmpty) {
        _showErrorSnackBar('Please provide a valid shipping address.');
        return;
      }

      final userId = authProvider.user!.id.toString();
      final pointProvider = Provider.of<PointProvider>(context, listen: false);

      // Step 1: Validate points redemption (if points were selected)
      if (widget.redeemedPoints > 0 && widget.pointsDiscount > 0) {
        // Validate redemption amount before proceeding
        final cartTotal = cartProvider.totalPrice;
        
        // Check if user has enough points
        if (pointProvider.currentBalance < widget.redeemedPoints) {
          _showErrorSnackBar(
              'Insufficient points. You have ${pointProvider.currentBalance} points, but need ${widget.redeemedPoints} points.');
          return;
        }

        // Validate redemption limits
        if (!PointService.isValidRedemptionAmount(
          widget.redeemedPoints,
          cartTotal,
          pointProvider.currentBalance,
        )) {
          final maxPoints = PointService.calculateMaxRedeemablePoints(cartTotal);
          _showErrorSnackBar(
              'Invalid points redemption. Maximum $maxPoints points allowed (${PointService.maxRedemptionPercent}% of order total).');
          return;
        }

        Logger.info('Points redemption validated: ${widget.redeemedPoints} points (-\$${widget.pointsDiscount.toStringAsFixed(2)})',
            tag: 'OrderConfirmation');
      }

      // Step 2: Create order with discount applied
      final order = await orderProvider.createOrder(
        userId: userId,
        cartItems: cartProvider.items,
        shippingAddress: widget.selectedShippingAddress!,
        billingAddress:
            widget.selectedBillingAddress ?? widget.selectedShippingAddress!,
        paymentMethod: widget.selectedPaymentMethod,
        shippingCost: 0.0,
        tax: 0.0,
        discount: widget.pointsDiscount, // Apply points discount to order total
        notes: (widget.redeemedPoints > 0) 
            ? 'Points redeemed: ${widget.redeemedPoints} points (-\$${widget.pointsDiscount.toStringAsFixed(2)})'
            : null,
        metadata: (widget.redeemedPoints > 0) ? {
          'redeemed_points': widget.redeemedPoints,
          'points_discount': widget.pointsDiscount,
          'points_redeemed_at': DateTime.now().toIso8601String(),
        } : null,
      );

      // Step 3: Redeem points AFTER successful order creation (with order ID)
      if (order != null && widget.redeemedPoints > 0 && widget.pointsDiscount > 0) {
        try {
          Logger.info('Redeeming ${widget.redeemedPoints} points for order ${order.id}',
              tag: 'OrderConfirmation');
          
          // Extract WooCommerce order ID from order metadata if available
          final wooOrderId = order.metadata?['woocommerce_id']?.toString();
          final orderIdForPoints = wooOrderId ?? order.id;

          // Redeem points with order ID (wait for backend sync to ensure points are deducted)
          final redemptionSuccess = await PointService.redeemPoints(
            userId: userId,
            points: widget.redeemedPoints,
            description: 'Points redeemed for order #${order.id}',
            orderId: orderIdForPoints,
            waitForSync: true, // Wait for backend sync to ensure points are deducted
          );
          
          // Update point provider state after redemption
          if (redemptionSuccess) {
            await pointProvider.loadBalance(userId);
            await pointProvider.loadTransactions(userId);
          }

          if (!redemptionSuccess) {
            // Points redemption failed after order creation
            // This is a critical issue - order was created but points weren't redeemed
            Logger.error(
                'CRITICAL: Order ${order.id} created but points redemption failed. Points: ${widget.redeemedPoints}',
                tag: 'OrderConfirmation');
            
            // Show warning but don't fail the order
            _showErrorSnackBar(
                'Order created successfully, but points redemption failed. Please contact support with order #${order.id}');
            
            // Still proceed with order success flow
          }
        } catch (e, stackTrace) {
          Logger.error('Error redeeming points after order creation: $e',
              tag: 'OrderConfirmation', error: e, stackTrace: stackTrace);
          
          // Show warning but don't fail the order
          _showErrorSnackBar(
              'Order created successfully, but points redemption encountered an error. Please contact support.');
        }
      }

      if (order != null) {
        print('✅ Order created successfully: ${order.id}');

        // Clear cart after successful order
        await cartProvider.clearCart();

        setState(() {
          _createdOrder = order;
        });

        _showSuccessSnackBar(
            'Order placed successfully! Order ID: ${order.id}');
      } else {
        print('❌ Order creation failed - returned null');
        
        // Get error message from order provider
        final orderProvider = Provider.of<OrderProvider>(context, listen: false);
        final errorMessage = orderProvider.errorMessage ?? 
            'Failed to create order. Please check your internet connection and try again.';
        
        _showErrorSnackBar(errorMessage);
      }
    } catch (e, stackTrace) {
      print('❌ Order creation error: $e');
      print('Stack trace: $stackTrace');
      
      // Extract user-friendly error message
      String errorMessage = 'Order creation failed';
      if (e.toString().contains('WooCommerce')) {
        errorMessage = 'Unable to connect to store. Please check your internet connection.';
      } else if (e.toString().contains('validation')) {
        errorMessage = 'Please check your order details and try again.';
      } else if (e.toString().contains('cart')) {
        errorMessage = 'Your cart appears to be empty. Please add items to cart.';
      } else {
        errorMessage = e.toString().replaceAll('Exception: ', '').trim();
        if (errorMessage.isEmpty || errorMessage == 'null') {
          errorMessage = 'Order creation failed. Please try again.';
        }
      }
      
      _showErrorSnackBar(errorMessage);
    } finally {
      setState(() {
        _isCreatingOrder = false;
      });
    }
  }

  String _getPaymentMethodText(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.creditCard:
        return 'Credit Card';
      case PaymentMethod.debitCard:
        return 'Debit Card';
      case PaymentMethod.mobilePayment:
        return 'Mobile Payment';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.cashOnDelivery:
        return 'Cash on Delivery';
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
