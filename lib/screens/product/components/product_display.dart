import 'package:ecommerce_int2/app_properties.dart';
import 'package:ecommerce_int2/models/product.dart';
import 'package:ecommerce_int2/screens/rating/rating_page.dart';
import 'package:ecommerce_int2/widgets/network_image_widget.dart';
import 'package:flutter/material.dart';

class ProductDisplay extends StatefulWidget {
  final Product product;

  const ProductDisplay({
    super.key,
    required this.product,
  });

  @override
  _ProductDisplayState createState() => _ProductDisplayState();
}

class _ProductDisplayState extends State<ProductDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleFavoriteTap() {
    setState(() {
      _isFavorite = !_isFavorite;
    });

    // Add bounce animation
    _controller.reset();
    _controller.forward();

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RatingPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: Stack(
              children: <Widget>[
                // Enhanced price display
                Positioned(
                  top: 30.0,
                  right: 0,
                  child: Container(
                    width: MediaQuery.of(context).size.width / 1.5,
                    height: 100,
                    padding: EdgeInsets.only(right: 24, left: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          darkGrey,
                          darkGrey.withValues(alpha: 0.9),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12.0),
                        bottomLeft: Radius.circular(12.0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.25),
                          offset: Offset(0, 6),
                          blurRadius: 12.0,
                        ),
                      ],
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Price',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            widget.product.formattedPrice,
                            style: const TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontWeight: FontWeight.w700,
                              fontFamily: "Montserrat",
                              fontSize: 32.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Enhanced product image
                Align(
                  alignment: Alignment(-1, 0),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 20.0, left: 20.0),
                    child: SizedBox(
                      height: screenAwareSize(240, context),
                      child: Stack(
                        children: <Widget>[
                          // Background glow effect
                          Container(
                            height: 200,
                            width: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  mediumYellow.withValues(alpha: 0.3),
                                  mediumYellow.withValues(alpha: 0.1),
                                  Colors.transparent,
                                ],
                                stops: [0.0, 0.7, 1.0],
                              ),
                            ),
                          ),

                          // Product image with Hero animation
                          Center(
                            child: Hero(
                              tag:
                                  'product_${widget.product.name}_${widget.product.image}',
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 20,
                                      offset: Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: NetworkImageWidget(
                                    imageUrl: widget.product.image,
                                    fit: BoxFit.contain,
                                    height: 200,
                                    width: 200,
                                    fallbackAsset: 'assets/headphones.png',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Enhanced favorite button
                Positioned(
                  left: 20.0,
                  bottom: 0.0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: RawMaterialButton(
                      onPressed: _handleFavoriteTap,
                      constraints:
                          const BoxConstraints(minWidth: 50, minHeight: 50),
                      elevation: 8.0,
                      shape: CircleBorder(),
                      fillColor: Color.fromRGBO(255, 255, 255, 0.9),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                          key: ValueKey(_isFavorite),
                          color: _isFavorite
                              ? Color.fromRGBO(255, 137, 147, 1)
                              : Color.fromRGBO(255, 137, 147, 1),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
